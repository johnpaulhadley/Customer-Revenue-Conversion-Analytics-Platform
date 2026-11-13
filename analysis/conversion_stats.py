"""Statistics helpers for the conversion analysis notebook.

All rates are proportions of sessions (or of sessions reaching an earlier
funnel step), so they are tested as binomial proportions:
- 95% confidence intervals use the Wilson method, which behaves well for small
  rates and small segments.
- Funnel step rates use the closed funnel, so every rate is between 0 and 1.
- Differences between two segments use a two-proportion z-test, with a 95%
  interval for the difference (Newcombe's method).
- p-values are adjusted with Holm's method within each family of tests, so
  running many comparisons does not inflate false positives.
Order values are skewed, so they are compared with a bootstrap interval for the
difference in means and a Mann-Whitney U test.
"""
import numpy as np
import pandas as pd
from scipy import stats
from statsmodels.stats.multitest import multipletests
from statsmodels.stats.proportion import (
    confint_proportions_2indep,
    proportion_confint,
    proportions_ztest,
)

# Closed funnel: each step counts sessions that also completed every earlier step.
FUNNEL = [
    ("sessions", "Session"),
    ("funnel_view_item", "Viewed a product"),
    ("funnel_add_to_cart", "Added to cart"),
    ("funnel_begin_checkout", "Began checkout"),
    ("funnel_add_shipping", "Added shipping"),
    ("funnel_add_payment", "Added payment"),
    ("funnel_purchase", "Purchased"),
]
VALUE_COLS = ["sessions", "purchase_sessions", "orders", "revenue_usd"]


def wilson(successes, trials):
    low, high = proportion_confint(successes, trials, alpha=0.05, method="wilson")
    return np.asarray(low), np.asarray(high)


def rate_table(df, by, num="purchase_sessions", den="sessions"):
    """Sum the counts for each segment and add the rate with its 95% interval."""
    cols = list(dict.fromkeys(VALUE_COLS + [num, den]))
    by = [by] if isinstance(by, str) else list(by)
    t = df.groupby(by, as_index=False)[cols].sum()
    t["rate"] = t[num] / t[den]
    t["ci_low"], t["ci_high"] = wilson(t[num], t[den])
    t["share_of_sessions"] = t["sessions"] / t["sessions"].sum()
    t["aov"] = t["revenue_usd"] / t["orders"]
    t["revenue_per_session"] = t["revenue_usd"] / t["sessions"]
    t["revenue_per_conversion"] = t["revenue_usd"] / t["purchase_sessions"]
    return t.sort_values(den, ascending=False).reset_index(drop=True)


def two_proportions(x1, n1, x2, n2):
    """Return (difference, ci_low, ci_high, p_value) for rate 1 minus rate 2."""
    _, p = proportions_ztest([x1, x2], [n1, n2])
    low, high = confint_proportions_2indep(x1, n1, x2, n2, method="newcomb", compare="diff")
    return x1 / n1 - x2 / n2, low, high, p


def compare_segments(df, by, num="purchase_sessions", den="sessions", reference=None, family=None):
    """Compare each segment's rate with a reference segment, or with all other sessions.

    With reference=None each segment is tested against the rest of the data,
    which suits dimensions with no natural baseline (channels, countries).
    """
    t = rate_table(df, by, num, den)
    rows = []
    for _, r in t.iterrows():
        seg = r[by]
        if reference is not None:
            if seg == reference:
                continue
            ref = t[t[by] == reference].iloc[0]
            x2, n2, label = ref[num], ref[den], reference
        else:
            x2, n2, label = t[num].sum() - r[num], t[den].sum() - r[den], "all other sessions"
        diff, low, high, p = two_proportions(r[num], r[den], x2, n2)
        rows.append({
            "family": family or by, "dimension": by, "segment": seg, "compared_with": label,
            "segment_rate": r[num] / r[den], "comparison_rate": x2 / n2,
            "difference": diff, "diff_ci_low": low, "diff_ci_high": high,
            "relative_difference": diff / (x2 / n2) if x2 else np.nan,
            "segment_trials": int(r[den]), "p_value": p,
        })
    return pd.DataFrame(rows)


def holm(tests):
    """Add Holm-adjusted p-values within each family and flag significance at 5%."""
    tests = tests.copy()
    tests["p_adjusted"] = np.nan
    for fam, idx in tests.groupby("family").groups.items():
        tests.loc[idx, "p_adjusted"] = multipletests(tests.loc[idx, "p_value"], method="holm")[1]
    tests["significant"] = tests["p_adjusted"] < 0.05
    return tests


def funnel_table(df, by=None):
    """Sessions reaching each step, the rate from the previous step and from the start."""
    groups = [("All", df)] if by is None else list(df.groupby(by))
    rows = []
    for seg, g in groups:
        totals = g[[c for c, _ in FUNNEL]].sum()
        for i, (col, label) in enumerate(FUNNEL):
            prev = totals[FUNNEL[i - 1][0]] if i else totals[col]
            rows.append({
                "segment": seg, "step_number": i, "step": label, "sessions_reaching": int(totals[col]),
                "rate_from_previous": totals[col] / prev if prev else np.nan,
                "rate_from_session": totals[col] / totals["sessions"],
            })
    out = pd.DataFrame(rows)
    out["lost_from_previous"] = (out.groupby("segment")["sessions_reaching"].shift(1) - out["sessions_reaching"]).fillna(0)
    return out


def funnel_step_tests(df, by, reference):
    """Test each step-to-step rate of every segment against the reference segment."""
    rows = []
    for i in range(1, len(FUNNEL)):
        num, den = FUNNEL[i][0], FUNNEL[i - 1][0]
        t = compare_segments(df, by, num=num, den=den, reference=reference, family=f"funnel by {by}")
        t.insert(3, "step", f"{FUNNEL[i - 1][1]} -> {FUNNEL[i][1]}")
        rows.append(t)
    return holm(pd.concat(rows, ignore_index=True))


def bootstrap_mean_diff(a, b, n=10_000, seed=7):
    """95% bootstrap interval for mean(a) - mean(b)."""
    rng = np.random.default_rng(seed)
    a, b = np.asarray(a, float), np.asarray(b, float)
    diffs = rng.choice(a, (n, a.size)).mean(1) - rng.choice(b, (n, b.size)).mean(1)
    return a.mean() - b.mean(), *np.percentile(diffs, [2.5, 97.5])


def bootstrap_mean_ci(a, n=10_000, seed=7):
    rng = np.random.default_rng(seed)
    a = np.asarray(a, float)
    return np.percentile(rng.choice(a, (n, a.size)).mean(1), [2.5, 97.5])


def compare_order_values(orders, by, reference):
    """Mean order value by segment with bootstrap intervals, tested against a reference."""
    ref = orders.loc[orders[by] == reference, "revenue_usd"]
    rows = []
    for seg, g in orders.groupby(by):
        v = g["revenue_usd"]
        low, high = bootstrap_mean_ci(v)
        row = {"family": f"order value by {by}", "dimension": by, "segment": seg, "orders": len(v),
               "mean_order_value": v.mean(), "mean_ci_low": low, "mean_ci_high": high,
               "median_order_value": v.median()}
        if seg != reference and len(v) >= 2:
            diff, dlow, dhigh = bootstrap_mean_diff(v, ref)
            row.update({"compared_with": reference, "difference": diff, "diff_ci_low": dlow,
                        "diff_ci_high": dhigh,
                        "p_value": stats.mannwhitneyu(v, ref, alternative="two-sided").pvalue})
        rows.append(row)
    out = pd.DataFrame(rows).sort_values("orders", ascending=False).reset_index(drop=True)
    tested = out["p_value"].notna()
    out.loc[tested, "p_adjusted"] = multipletests(out.loc[tested, "p_value"], method="holm")[1]
    out["significant"] = out["p_adjusted"] < 0.05
    return out


def size_gap(sessions, rate, target_rate, value_per_conversion, fractions=(0.10, 0.25, 0.50)):
    """Extra conversions and revenue if a segment closed part of the gap to a target rate."""
    gap = max(target_rate - rate, 0)
    out = {}
    for f in fractions:
        extra = sessions * gap * f
        out[f"extra_conversions_{int(f * 100)}pct"] = extra
        out[f"extra_revenue_{int(f * 100)}pct"] = extra * value_per_conversion
    return out
