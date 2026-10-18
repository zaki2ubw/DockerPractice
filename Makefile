COMPOSE = docker compose -f srcs/docker-compose.yml

SETUP = ./srcs/requirements/tools/setup-host.sh

all: up

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

setup:
	$(SETUP)

logs:
	$(COMPOSE) logs

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down

fclean:
	$(COMPOSE) down -v --rmi all

re: fclean all

.PHONY: all up down start stop restart setup logs ps clean fclean re
