#!/usr/bin/env bash

SPOTO_BASE_DIR=`eval echo ~/spoto`
DOCKER_COMPOSE_1=docker-compose.yml
DOCKER_COMPOSE_2=docker-compose.dev.yml # TODO: dev -> prod
MYSQL_PASSWORD=

if [ ! -f $SPOTO_BASE_DIR ]; then
  mkdir -p $SPOTO_BASE_DIR
fi

echo "Cloning repos"
git -C $SPOTO_BASE_DIR clone --branch dev https://betaparticle@bitbucket.org/spoto77/spoto.git
git -C $SPOTO_BASE_DIR clone --branch dev https://betaparticle@bitbucket.org/spoto77/spoto-docker.git
git -C $SPOTO_BASE_DIR clone --branch dev https://betaparticle@bitbucket.org/spoto77/spoto-whmcs.git
git -C $SPOTO_BASE_DIR clone --branch dev https://betaparticle@bitbucket.org/spoto77/spoto-whmcs-server-module.git
git -C $SPOTO_BASE_DIR clone --branch dev https://betaparticle@bitbucket.org/spoto77/spoto-webhooks-server.git

echo "Looking for docker-compose"
which docker-compose
if [ $? != 0 ]; then
  echo "Installing docker-compose"
  sudo mkdir -p /opt/bin
  sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /opt/bin/docker-compose
  sudo chmod +x /opt/bin/docker-compose
fi

echo "Creating configs"
cd $SPOTO_BASE_DIR/spoto-docker
if [ ! -f .env ]; then
  cp .env.example .env
fi
cd $SPOTO_BASE_DIR/spoto-webhooks-server
if [ ! -f .env ]; then
  cp .env.example .env
fi

echo "Building images"
cd $SPOTO_BASE_DIR/spoto-docker
docker-compose -f $DOCKER_COMPOSE_1 -f $DOCKER_COMPOSE_2 build
cd $SPOTO_BASE_DIR/spoto-whmcs-server-module/vue-app/.docker/
docker build -t spoto/vie-cli:latest .

echo "Running containers"
cd $SPOTO_BASE_DIR/spoto-docker
docker-compose -f $DOCKER_COMPOSE_1 -f $DOCKER_COMPOSE_2 up -d
cd $SPOTO_BASE_DIR/spoto-whmcs-server-module/vue-app
docker run -it --rm -v `pwd`:/usr/src/vue-app -w /usr/src/vue-app --name vuejs -itd -p 8081:8080 spoto/vie-cli:latest yarn serve

echo "Creating database"
docker exec -it spoto-docker_whmcs-mysql_1 /bin/bash -c "mysql -u root -p$MYSQL_PASSWORD -e 'create database whmcs'"

echo "Importing WHMCS database tables"
docker cp $SPOTO_BASE_DIR/spoto-docker/whmcs.sql spoto-docker_whmcs-mysql_1:/tmp/whmcs.sql
docker exec -it spoto-docker_whmcs-mysql_1 /bin/bash -c "mysql -u root -p$MYSQL_PASSWORD whmcs < /tmp/whmcs.sql"

echo "Running webhook-phpfpm database migrations and seeding"
docker-compose exec webhook-phpfpm php /code/artisan migrate
docker-compose exec webhook-phpfpm php /code/artisan db:seed

echo "Updating WHMCS SystemURL"
docker exec -it spoto-docker_whmcs-mysql_1 /bin/bash -c "mysql -u root -p$MYSQL_PASSWORD whmcs -e \"UPDATE tblconfiguration SET value='http://localhost:88' WHERE setting='SystemURL'\""

echo "All done!"
