# Load variables from .env (if present) and pass them to every command
-include .env
export

DBT_FLAGS = --project-dir dbt --profiles-dir dbt

.PHONY: install check build dev docs report all clean site

install:
	pip install -r requirements.txt

check:
	dbt debug $(DBT_FLAGS)

build:
	dbt build $(DBT_FLAGS)

# Cheap development run: one week of data instead of three months
dev:
	dbt build $(DBT_FLAGS) --vars '{"start_date": "20201201", "end_date": "20201207"}'

docs:
	dbt docs generate $(DBT_FLAGS) && dbt docs serve $(DBT_FLAGS)

report:
	python analysis/report.py

all: build report

clean:
	rm -rf dbt/target dbt/logs logs

# Build the dbt docs as one web page and put it in a Desktop folder for Netlify
site:
	dbt docs generate $(DBT_FLAGS) --static
	mkdir -p ~/Desktop/ga4-docs-site
	cp dbt/target/static_index.html ~/Desktop/ga4-docs-site/index.html
