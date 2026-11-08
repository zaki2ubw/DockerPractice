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

# .env と各種パスワードファイルを生成する
# ホスト環境の設定（setup）は行わない
init:
# .env.example から .env を生成する（既存ファイルは保持）
	@if [ ! -e srcs/.env ]; then \
		cp srcs/.env.example srcs/.env; \
		echo "Created srcs/.env"; \
	else \
		echo "Preserved srcs/.env"; \
	fi

# パスワードファイルを生成する（所有者のみ読み書き可能）
# 既存ファイルは保持し、空ファイルが存在する場合はエラーにする
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

	@echo "Initialization complete."

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
