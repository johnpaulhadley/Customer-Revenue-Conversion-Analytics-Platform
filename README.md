# Customer Revenue & Conversion Analytics Platform

**Status: in progress.** Scope, source profile, dbt models and cost measurement are done; the statistical analysis is being run and dashboards are next.

## Business question
Where is the Google Merchandise Store losing revenue across traffic, conversion, products and customers, and what is a realistic improvement worth in dollars?

## Data
[Google Analytics 4 sample e-commerce dataset](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset) in BigQuery, November 2020 to January 2021.

## Stack
BigQuery, dbt, Python (pandas, SciPy, statsmodels), Tableau Public.

## Documentation
- [Business case, scope and KPI definitions](docs/business_case.md)
- [Data model](docs/data_model.md)
- [Source data profile](docs/data_profile.md)
- [BigQuery cost results](docs/cost_results.md)
- [Conversion analysis notebook](notebooks/conversion_analysis.ipynb)

## Run locally
Needs Python 3.11+, the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) and a Google Cloud project with BigQuery enabled.
```
gcloud auth application-default login
cp .env.example .env                      # then set GCP_PROJECT
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
set -a; source .env; set +a
python analysis/profile_source.py         # source profile and baseline scan sizes
cd dbt && dbt build --profiles-dir . && cd ..
python analysis/measure_cost.py           # bytes saved by the model design
python analysis/export_marts.py           # marts to data/exports/ for the notebook and Tableau
jupyter nbconvert --to notebook --execute --inplace notebooks/conversion_analysis.ipynb
```
