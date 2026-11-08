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

init: setup
	@umask 077; mkdir -p secrets; \
	for name in db_password db_root_password wp_admin_password wp_user_password; do \
		file="secrets/$$name.txt"; \
		if [ ! -s "$$file" ]; then \
			if [ -e "$$file" ]; then \
				echo "ERROR: $$file is empty"; exit 1; \
			fi; \
			head -c 24 /dev/urandom | base64 > "$$file"; \
			echo "Created $$file"; \
		else \
			echo "Preserved $$file"; \
		fi; \
	done
	@echo "Initialization complete. Run 'make' to start."

logs:
	$(COMPOSE) logs

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down

fclean:
	$(COMPOSE) down -v --rmi all

re: fclean all

.PHONY: all up down start stop restart setup init logs ps clean fclean re
