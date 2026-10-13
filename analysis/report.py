"""Draw the README charts from the dbt marts in BigQuery.

Run after `dbt build`:  python analysis/report.py
Needs GCP_PROJECT set (in .env or your shell) and `gcloud auth application-default login`.
"""
import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # render to files, no display needed
import matplotlib.pyplot as plt
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "docs" / "images"
DATASET = os.getenv("DBT_DATASET", "ga4_analytics")


def load_env() -> None:
    """Read GCP_PROJECT from .env if it isn't already set (avoids an extra dependency)."""
    env_file = ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def main() -> None:
    load_env()
    project = os.getenv("GCP_PROJECT")
    if not project or project == "your-gcp-project-id":
        raise SystemExit("Set GCP_PROJECT in your .env file first.")

    client = bigquery.Client(project=project)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Overall funnel
    funnel = client.query(f"""
        select
            sum(sessions)                as sessions,
            sum(view_item_sessions)      as view_item,
            sum(add_to_cart_sessions)    as add_to_cart,
            sum(begin_checkout_sessions) as begin_checkout,
            sum(purchase_sessions)       as purchase
        from `{project}.{DATASET}.fct_funnel_daily`
    """).to_dataframe().iloc[0]

    steps = ["Sessions", "Viewed item", "Added to cart", "Began checkout", "Purchased"]
    values = [int(v) for v in funnel.values]
    fig, ax = plt.subplots(figsize=(9, 4.8))
    bars = ax.barh(steps[::-1], values[::-1])
    for bar, value in zip(bars, values[::-1]):
        share = value / values[0]
        ax.text(bar.get_width(), bar.get_y() + bar.get_height() / 2,
                f"  {value:,} ({share:.1%})", va="center")
    ax.set_title("Shopping funnel: share of all sessions reaching each step")
    ax.set_xlim(0, values[0] * 1.3)
    ax.set_xlabel("Sessions")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "funnel.png", dpi=120)
    plt.close(fig)

    # 2. Revenue by channel under each attribution model
    attribution = client.query(f"""
        select model, channel, attributed_revenue
        from `{project}.{DATASET}.fct_channel_attribution`
    """).to_dataframe()
    pivot = (attribution
             .pivot(index="channel", columns="model", values="attributed_revenue")
             .fillna(0))
    pivot = pivot.loc[pivot.sum(axis=1).sort_values(ascending=False).index]
    pivot = pivot[[c for c in ["first_touch", "last_non_direct_touch", "linear"] if c in pivot]]
    ax = pivot.plot(kind="bar", figsize=(10, 5.2), width=0.8)
    ax.set_title("Revenue credited to each channel, by attribution model")
    ax.set_xlabel("")
    ax.set_ylabel("Attributed revenue (USD)")
    ax.legend(title="Model")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    plt.savefig(OUT_DIR / "attribution_comparison.png", dpi=120)
    plt.close()

    # 3. Conversion rate by channel and device
    rates = client.query(f"""
        select
            channel,
            device_category,
            safe_divide(sum(purchase_sessions), sum(sessions)) as conversion_rate
        from `{project}.{DATASET}.fct_funnel_daily`
        where device_category in ('desktop', 'mobile')
        group by 1, 2
        having sum(sessions) >= 500
    """).to_dataframe()
    if rates.empty:
        print("Skipped conversion chart: no channel has 500+ sessions in the date range.")
    else:
        pivot = rates.pivot(index="channel", columns="device_category", values="conversion_rate")
        pivot = pivot.sort_values(pivot.columns[0], ascending=False)
        ax = (pivot * 100).plot(kind="bar", figsize=(9, 5), width=0.75)
        ax.set_title("Session conversion rate by channel and device")
        ax.set_xlabel("")
        ax.set_ylabel("Conversion rate (%)")
        ax.legend(title="Device")
        plt.xticks(rotation=30, ha="right")
        plt.tight_layout()
        plt.savefig(OUT_DIR / "conversion_by_channel_device.png", dpi=120)
        plt.close()

    print(f"Charts saved to {OUT_DIR}")


if __name__ == "__main__":
    main()
