# Tableau Public build guide

This guide builds a five-page Tableau Public dashboard from the CSV files in `data/exports/`. Work through it in order. Expect three to four hours the first time.

| Page | Question it answers |
|---|---|
| Overview | How is the store doing, and who converts? |
| Checkout Funnel | Where do new visitors fall behind returning ones? |
| Channels | Which traffic sources convert, and how much does tracking distort that? |
| Products | Which merchandise brings the revenue? |
| Opportunity | What would closing the gap be worth, and how would we test it? |

## 0. Before you start

1. Install **Tableau Public** for Mac from [public.tableau.com](https://public.tableau.com) (Create > Download the app) and create a free Tableau Public account. It runs natively on the Mac.
2. Pull the latest files: in Terminal, from the project folder, run `git pull`.
3. Tableau Public saves workbooks to your Tableau Public profile. Save early and often (**File > Save to Tableau Public**). You can hide the viz from your profile until it is finished (see section 7).

**Field names.** Tableau tidies CSV column names when it loads them: `funnel_view_item` appears as **Funnel View Item** and `revenue_usd` as **Revenue Usd**. This guide uses the tidied names. If yours differ slightly, use the one that matches.

## 1. Load the data

Open Tableau Public, choose **Text file** under Connect, and open `data/exports/daily_sessions.csv`. For each further file, use **Data > New Data Source > Text file**. Rename each data source (right-click its name at the top of the Data pane > Rename):

| File | Rename the data source to | Rows are |
|---|---|---|
| `data/exports/daily_sessions.csv` | Sessions | day x channel x device x visitor type x country group |
| `data/exports/product_monthly.csv` | Products | product x month |
| `data/exports/analysis/channel_attribution.csv` | Attribution | one per channel |
| `data/exports/analysis/opportunities.csv` | Opportunities | one per sized opportunity |
| `data/exports/analysis/ab_test_plan.csv` | Test Plan | one per scenario |

Keep them as separate data sources. Each page reads from one source, so no joins or blending are needed.

Check the data types in each source (the icon next to each field in the Data pane):
- **Session Date** in Sessions and **Month** in Products: Date. If either shows as text (Abc), click the icon and choose Date.
- All counts and dollar columns: Number (whole or decimal).
- **User Type**, **Channel**, **Device Category**, **Country Group**, **Item Category**, **Item Name**, **Opportunity**: String.

Rename two fields in Sessions for readability (right-click > Rename): **User Type** to **Visitor Type**, and **Device Category** to **Device**.

## 2. Calculated fields

Create these in the **Sessions** data source (**Analysis > Create Calculated Field**). Every rate is a ratio of sums, so it stays correct for any filter. Never average a rate.

```
Conversion Rate
SUM([Purchase Sessions]) / SUM([Sessions])

Revenue
SUM([Revenue Usd])

Average Order Value
SUM([Revenue Usd]) / SUM([Orders])

Revenue per Session
SUM([Revenue Usd]) / SUM([Sessions])

Cart Abandonment
1 - SUM([Cart Purchase Sessions]) / SUM([Add To Cart Sessions])
```

95% confidence interval for the conversion rate (Wilson method, the same as the notebook). 3.8416 is 1.96 squared:

```
CI Low
([Conversion Rate] + 1.9208 / SUM([Sessions])
 - 1.96 * SQRT([Conversion Rate] * (1 - [Conversion Rate]) / SUM([Sessions])
               + 0.9604 / (SUM([Sessions]) * SUM([Sessions]))))
/ (1 + 3.8416 / SUM([Sessions]))

CI High
([Conversion Rate] + 1.9208 / SUM([Sessions])
 + 1.96 * SQRT([Conversion Rate] * (1 - [Conversion Rate]) / SUM([Sessions])
               + 0.9604 / (SUM([Sessions]) * SUM([Sessions]))))
/ (1 + 3.8416 / SUM([Sessions]))

CI Width
[CI High] - [CI Low]
```

Closed-funnel step rates. The number at the start of each name keeps the steps in order on charts:

```
1 Viewed a product
SUM([Funnel View Item]) / SUM([Sessions])

2 Added to cart
SUM([Funnel Add To Cart]) / SUM([Funnel View Item])

3 Began checkout
SUM([Funnel Begin Checkout]) / SUM([Funnel Add To Cart])

4 Added shipping
SUM([Funnel Add Shipping]) / SUM([Funnel Begin Checkout])

5 Added payment
SUM([Funnel Add Payment]) / SUM([Funnel Add Shipping])

6 Purchased
SUM([Funnel Purchase]) / SUM([Funnel Add Payment])
```

Channel helpers:

```
Self-referral flag
IF [Channel] = "Self-referral" THEN "Store's own domain" ELSE "Other channels" END
```

In the **Opportunities** data source:

```
Range Width
SUM([Extra Revenue 50Pct]) - SUM([Extra Revenue 10Pct])
```

**Formatting** (right-click a field > Default Properties > Number Format):
- Conversion Rate, CI Low, CI High: Percentage, 2 decimals.
- The six step rates and Cart Abandonment: Percentage, 0 decimals.
- Revenue and Revenue Usd: Currency (Custom), 0 decimals. Average Order Value and Revenue per Session: Currency, 2 decimals.
- Sessions, Orders and other counts: Number, 0 decimals, with thousands separators.

**Colours.** Use one set throughout: Returning visitors **#2A78D6** (blue), New visitors **#EB6834** (orange). Single-measure bars use the blue. To set them, click Colour on the Marks card > Edit Colours, select each value, and type the hex code in the colour picker.

## 3. Worksheets

Create each worksheet with the **New Worksheet** tab at the bottom. Name it as shown, since the dashboards refer to these names.

### Overview worksheets (Sessions source)

**KPI Tiles**
- Drag **Measure Values** to Text on the Marks card, and **Measure Names** to Columns.
- In the Measure Values card, keep only: SUM(Sessions), Conversion Rate, SUM(Orders), Revenue, Average Order Value, Revenue per Session. Remove anything else.
- Rename the column headers (right-click a header > Edit Alias): Sessions, Conversion, Orders, Revenue, Avg order, Revenue / session.
- Text: font size 20, bold. Format > Borders: none. Hide the row header if one appears.

**Revenue by Week**
- Columns: **Session Date**. Click the pill's dropdown arrow and choose **Week Number** from the lower group of options (the green, continuous one), so the axis runs week by week.
- Rows: **Revenue**. Mark type: Line.
- Title: "Weekly revenue".

**Conversion by Week**
- Same as above, with **Conversion Rate** on Rows. Title: "Weekly conversion rate". Keep it as a separate sheet: never put revenue and conversion on two axes of one chart.

**Conversion by Visitor Type** (confidence interval chart)
1. Rows: **Visitor Type**. Columns: **CI Low**.
2. Marks card: change the mark type to **Gantt Bar**. Drag **CI Width** to Size. This draws the 95% interval as a bar from CI Low to CI High.
3. Drag **Conversion Rate** to Columns, to the right of CI Low. Right-click the new pill > **Dual Axis**, then right-click the top axis > **Synchronize Axis**, then hide the top axis (right-click > untick Show Header). Both axes now share one scale.
4. On the Conversion Rate marks card choose **Circle**, size medium, colour by **Visitor Type**. Add **Conversion Rate** to Label.
5. Tooltip: "<Visitor Type>: <Conversion Rate> (95% CI <CI Low> to <CI High>), <SUM(Sessions)> sessions".
6. Title: "Conversion rate with 95% confidence interval".

**Conversion by Device**
- Duplicate Conversion by Visitor Type (right-click the tab > Duplicate) and replace Visitor Type with **Device** on Rows and on Colour (set the circle colour to the single blue).

### Checkout Funnel worksheets (Sessions source)

**Funnel Step Rates**
1. Drag **Measure Values** to Columns and **Measure Names** to Rows.
2. In the Measure Values card, remove everything and add the six step-rate fields (1 Viewed a product to 6 Purchased). Their number prefixes keep them in order; if they are not, sort Measure Names alphabetically.
3. Drag **Visitor Type** to Rows, to the right of Measure Names, and to Colour. Each step now has a returning bar and a new bar.
4. Label: Measure Values, 0 decimals. Axis fixed from 0 to 1 (right-click axis > Edit Axis > Fixed).
5. Title: "Share continuing to the next step (closed funnel)".

**Funnel Volume**
- Columns: Measure Values. Rows: Measure Names.
- Measure Values: SUM(Sessions), SUM(Funnel View Item), SUM(Funnel Add To Cart), SUM(Funnel Begin Checkout), SUM(Funnel Add Shipping), SUM(Funnel Add Payment), SUM(Funnel Purchase). Drag them into that order in the Measure Values card.
- Edit the row aliases to: Sessions, Viewed a product, Added to cart, Began checkout, Added shipping, Added payment, Purchased.
- Colour: Visitor Type (stacked bars). Label: Measure Values.
- Title: "Sessions reaching each step".

**Cart Abandonment by Visitor Type**
- Rows: Visitor Type. Columns: Cart Abandonment. Colour: Visitor Type. Label on.
- Title: "Carts not bought in the same session".

### Channels worksheets

**Channel Conversion** (Sessions source)
- Duplicate Conversion by Device and replace Device with **Channel** on Rows. Circle colour: single blue.
- Drag **Channel** to Filters and **exclude Not recorded** (sessions with no source cannot be assigned a channel).
- Sort Channel by Conversion Rate, descending.
- Title: "Conversion per session by channel, with 95% CI".

**Channel Revenue** (Sessions source)
- Rows: Channel (exclude Not recorded, as above). Columns: Revenue. Sort descending.
- Colour: **Self-referral flag**. Store's own domain in orange (#EB6834), Other channels in blue.
- Label: Revenue.
- Title: "Revenue by channel".

**Per Session vs First Touch** (Attribution source)
- Rows: **Channel**. Columns: Measure Values.
- Measure Values: AVG(Session Conversion) and AVG(Visitor To Buyer). (One row per channel, so AVG returns the value itself.)
- Drag **Measure Names** to Colour and to Rows (right of Channel) for side-by-side bars. Alias them: "Per session" and "Visitors first brought who bought".
- Format both as Percentage, 2 decimals. Label on.
- Title: "Judged per session vs by the customers a channel brings".

### Products worksheets (Products source)

**Revenue by Group**
- Rows: **Item Category**. Columns: SUM(Item Revenue Usd). Sort descending. Label on, currency, 0 decimals.
- Title: "Item revenue by merchandise group".

**Top Products**
- Rows: **Item Name**. Columns: SUM(Item Revenue Usd). Colour: Item Category.
- Drag Item Name to Filters > **Top** tab > By field: Top 15 by Sum of Item Revenue Usd. Sort descending.
- Title: "Top 15 products by revenue".

**Group by Month**
- Columns: **MONTH(Month)** (discrete). Rows: Item Category. Mark type: Square. Colour and Label: SUM(Item Revenue Usd).
- Colour: a single-hue sequential palette (Blue), light to dark.
- Title: "Item revenue by group and month".

### Opportunity worksheets

**Opportunity Range** (Opportunities source)
1. Rows: **Opportunity**. Columns: SUM(Extra Revenue 10Pct). Mark type: Gantt Bar. Size: **Range Width**. This draws each range from the 10% to the 50% scenario.
2. Add SUM(Extra Revenue 25Pct) to Columns, make it **Dual Axis**, **Synchronize Axis**, hide the top axis, mark type Circle. Label it with SUM(Extra Revenue 25Pct), currency, 0 decimals.
3. Sort Opportunity by SUM(Extra Revenue 25Pct), descending.
4. Title: "Extra revenue over three months: dot = 25% of the gap closed, bar = 10% to 50%".

**Test Plan** (Test Plan source)
- Rows: Gap Closed (discrete), Baseline Rate, Target Rate (all as dimensions: right-click > Dimension, discrete). Text: SUM(Sessions Per Variant) and SUM(Weeks At Current Traffic).
- Formats: Gap Closed, Baseline Rate and Target Rate as Percentage 0 decimals; weeks 0 decimals.
- Title: "A/B test size for the payment step (80% power, 5% significance)".

## 4. Filters

On each Sessions worksheet, right-click a filter and choose **Apply to Worksheets > All Using This Data Source**, so one filter controls a whole page.

- **Month:** drag Session Date to Filters > Months, select all, then Show Filter. Display as a single-value dropdown with "All".
- **Device**, **Visitor Type**, **Country Group**, **Channel**: drag each to Filters, select all, Show Filter, dropdown with "All".

The Channel Conversion and Channel Revenue sheets keep their own filter excluding Not recorded. A page filter set to All cannot bring it back, because Tableau applies both.

On Products sheets, add **Item Category** and **MONTH(Month)** filters, applied to all sheets using the Products source.

## 5. Dashboards

**Dashboard > New Dashboard** for each page. Size: **Fixed size, 1200 x 900** (Dashboard pane > Size). Use a **Vertical** container for the page and **Horizontal** containers for rows. Put a title text box at the top of every page with the same style, and the page's filters in one row under it.

**Overview**
- Title: "Google Merchandise Store: revenue and conversion, Nov 2020 to Jan 2021".
- Row 1: KPI Tiles.
- Row 2: Revenue by Week | Conversion by Week.
- Row 3: Conversion by Visitor Type | Conversion by Device.
- Text box: "Returning visitors convert at more than four times the rate of new ones. Mobile and desktop convert at the same rate: the gap is who the visitor is, not the device. Bars show 95% confidence intervals. Revenue is understated 1 to 10 November (purchases without transaction IDs are excluded) and from 26 January (purchases recorded without revenue); the last weekly point is a single day."

**Checkout Funnel**
- Filters: Month, Device, Channel, Country Group.
- Row 1: Funnel Step Rates (wide).
- Row 2: Funnel Volume | Cart Abandonment by Visitor Type.
- Text box: "Of new visitors who enter shipping details, 48% go on to enter payment details, against 83% of returning visitors. Once payment is entered, both complete at similar rates. A session counts at a step only if it completed every earlier step in that session."

**Channels**
- Filters: Month, Device, Visitor Type.
- Row 1: Channel Conversion | Channel Revenue.
- Row 2: Per Session vs First Touch.
- Text box: "Self-referral: visits that restarted on the store's own domain, often on return from checkout. They carry a third of revenue but no outside site sent the visitor. A quarter of sessions have no recorded source and are left out. Per session, paid search converts at 0.61%; its first-time visitors go on to buy as often as organic search's (1.27% vs 1.31%)."
- Note under Per Session vs First Touch: "Whole period; not affected by filters."

**Products**
- Filters: Item Category, Month.
- Row 1: Revenue by Group | Top Products.
- Row 2: Group by Month.
- Text box: "Purchases only. In this data, product-view and add-to-cart events carry long product lists (about 36 and 44 per session), so per-product view and add rates are not reliable."

**Opportunity**
- Row 1: Opportunity Range (wide).
- Row 2: Test Plan | text box with assumptions:
  "Each estimate closes part of a significant gap between new and returning visitors, valued at new visitors' revenue per conversion. Estimates overlap, so they are alternatives, not a total. Counted revenue in the period was $307,640. Returning visitors arrive with more intent, so closing the whole gap is not assumed."

Hide the worksheets so only the five dashboards show: right-click any dashboard tab > **Hide All Sheets**.

## 6. Checks before publishing

With all filters set to All:

| Check | Expected |
|---|---|
| KPI Tiles: Sessions | 360,129 |
| Conversion | 1.35% |
| Orders | 4,451 |
| Revenue | $307,640 |
| Average order | $69.12 |
| Revenue per session | $0.85 |
| Conversion, Returning / New | 3.10% / 0.68% |
| Conversion, desktop / mobile | 1.32% / 1.39% (intervals overlap) |
| Funnel step 5 (added payment), New / Returning | 48% / 83% |
| Cart abandonment, all visitors | 81% |
| Channel Revenue, Self-referral | $100,254 (largest bar) |
| Channel Conversion, Paid Search | 0.61% |
| Products: Apparel | $178,241, largest group |
| Top product | Google Zip Hoodie F/C, $10,488 |
| Opportunity: new visitors' carts, 25% | $18,929 |

Also check that:
- Selecting Visitor Type = New on the Overview changes every chart on the page.
- Not recorded never appears in the channel charts.
- No chart shows a rate as a SUM of rates (all rates come from the calculated fields).

## 7. Publish

1. **File > Save to Tableau Public As...**, sign in, and name the workbook "Google Merchandise Store Revenue and Conversion".
2. The published viz opens in the browser. Under its settings (the gear or "Edit Details"), add a description and set **Show views as tabs** on, so all five pages are reachable.
3. While you are still working on it, you can turn off **Show Viz on Profile**; turn it back on when finished.
4. Copy the viz's URL and send it to me for the README.
5. Screenshots: on each page, use **Download > Image** in Tableau Public (or Cmd+Shift+4 on the Mac) and save them as `images/dashboard_overview.png`, `images/dashboard_funnel.png`, `images/dashboard_channels.png`, `images/dashboard_products.png` and `images/dashboard_opportunity.png`. **Download > PDF** with "This workbook" selected saves all pages as `dashboards/revenue_conversion_dashboard.pdf`.
