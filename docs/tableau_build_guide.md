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

Tableau may give **Country Group** a globe icon, guessing it is a map field. "Rest of world" is not a country, so right-click it > **Geographic Role > None**.

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

Has recorded source
[Channel] != "Not recorded"
```

`Has recorded source` is how the channel charts leave out sessions with no source. A sheet can hold only one filter per field, and Channel already carries the page-wide filter, so excluding Not recorded through Channel itself would change every page.

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

**Measure Names filters.** Several sheets use Measure Names and Measure Values to show a chosen set of fields. Tableau ticks every field by default, so whenever you drag **Measure Names** to Filters, click **None** first and then tick only the fields listed. Aliases you set on Measure Names apply across the whole workbook.

### Overview worksheets (Sessions source)

**KPI Tiles**
1. Drag **Measure Names** to Filters > **None** > tick Sessions, Conversion Rate, Orders, Revenue, Average Order Value, Revenue per Session.
2. Drag **Measure Names** to Columns and **Measure Values** onto Text. Order the fields in the Measure Values card as listed above.
3. Rename the column headers (right-click > Edit Alias): Sessions, Conversion, Orders, Revenue, Avg order, Revenue / session.
4. Text: size 18 to 20, bold. On the dashboard, hide the sheet title.

Do not double-click the six fields instead: that puts each one on both Rows and Columns and builds a grid of charts.

**Revenue by Week**
- Columns: **Session Date**. Click the pill's dropdown and choose **Week Number** from the lower group of options (green, continuous).
- Rows: **Revenue**. Mark type: Line. Title: "Weekly revenue".

**Conversion by Week**
- Duplicate Revenue by Week and drop **Conversion Rate** onto the Revenue pill. Title: "Weekly conversion rate". Keep it a separate sheet: never put revenue and conversion on two axes of one chart.

**Conversion by Visitor Type** (confidence interval chart)
1. Rows: **Visitor Type**. Columns: **CI Low**. Mark type: **Gantt Bar**. Size: **CI Width**. Colour: light grey. This draws the 95% interval as a bar from CI Low to CI High.
2. Drag **Conversion Rate** to Columns, right of CI Low. Right-click it > **Dual Axis**. Right-click the top axis > **Synchronize Axis**, then untick **Show Header**.
3. On the AGG(Conversion Rate) marks tab: mark type **Circle**, Colour **Visitor Type** (New #EB6834, Returning #2A78D6), Label **Conversion Rate**. Nothing on Size: CI Width belongs only on the Gantt tab. Remove Measure Names from Colour on any tab if Tableau adds it.
4. Bottom axis title: "Conversion rate". Tooltip: "<Visitor Type>: <AGG(Conversion Rate)> (95% CI <AGG(CI Low)> to <AGG(CI High)>), <SUM(Sessions)> sessions".
5. Title: "Conversion rate with 95% confidence interval".

**Conversion by Device**
- Duplicate Conversion by Visitor Type, drop **Device** onto the Visitor Type pill on Rows, remove Visitor Type from Colour and set the circles to #2A78D6.

### Checkout Funnel worksheets (Sessions source)

**Funnel Step Rates**
1. Measure Names to Filters > **None** > tick the six step fields (1 Viewed a product to 6 Purchased).
2. Measure Names to Rows, Measure Values to Columns. **Visitor Type** to Rows (right of Measure Names) and to Colour. Measure Values to Label.
3. Axis: Edit Axis > Fixed 0 to 1; Format > Scale > Numbers > Percentage, 0 decimals. Title the axis "Share continuing to the next step".
4. If labels show 0 and 1, the step fields still have a whole-number default format: set each to Percentage, 0 decimals (section 2).
5. Title: "Share continuing to the next step (closed funnel)".

**Funnel Volume** (a number table: on a bar chart, 360,129 sessions would dwarf 2,848 purchases)
1. Measure Names to Filters > **None** > tick Sessions, Funnel View Item, Funnel Add To Cart, Funnel Begin Checkout, Funnel Add Shipping, Funnel Add Payment, Funnel Purchase.
2. Measure Names to Rows, **Visitor Type** to Columns, Measure Values onto Text. Order the fields in the Measure Values card as listed.
3. Row aliases: Sessions, Viewed a product, Added to cart, Began checkout, Added shipping, Added payment, Purchased.
4. **Analysis > Totals > Show Row Grand Totals**. Title: "Sessions reaching each step".

**Cart Abandonment**
- Rows: Visitor Type. Columns: Cart Abandonment. Colour: Visitor Type. Label on. Axis fixed 0 to 1.
- Title: "Carts not bought in the same session".

### Channels worksheets

**Channel Conversion** (Sessions source)
- Duplicate Conversion by Device and drop **Channel** onto the Device pill.
- Drag **Has recorded source** to Filters and keep **True** only.
- Sort Channel descending by Conversion Rate.
- Title: "Conversion per session by channel, with 95% CI".

**Channel Revenue** (Sessions source)
- Rows: Channel. Columns: Revenue. Filter: **Has recorded source** = True. Sort descending.
- Colour: **Self-referral flag**. Store's own domain #EB6834, Other channels #2A78D6. Label: Revenue.
- Title: "Revenue by channel".

**Per Session vs First Touch** (Attribution source)
1. Set Session Conversion and Visitor To Buyer to Percentage, 2 decimals (Default Properties).
2. Measure Names to Filters > **None** > tick Session Conversion and Visitor To Buyer.
3. Rows: **Channel**, then **Measure Names**. Colour: Measure Names. Columns and Label: Measure Values.
4. Aliases: "Per session" and "First-touch visitors who bought"; drag Per session above the other. Colours: Per session #2A78D6, First-touch #1BAF7A.
5. Axis: Format > Numbers > Percentage, 1 decimal; title "Conversion rate".
6. Title: "Judged per session vs by the visitors a channel first brought".

### Products worksheets (Products source)

First set **Item Revenue Usd** (in this source) to Currency (Custom), 0 decimals.

**Revenue by Group**
- Rows: **Item Category**. Columns and Label: Item Revenue Usd. Sort descending. Axis title: "Revenue".
- Title: "Item revenue by merchandise group".

**Top Products**
- Rows: **Item Name**, then **Item Category**. Columns and Label: Item Revenue Usd.
- Item Name to Filters > **Top** tab > Top 15 by Sum of Item Revenue Usd. Sort descending. Widen the name column so names show in full.
- Title: "Top 15 products by revenue".

**Group by Month**
- Columns: **Month**, set to **Month** from the lower (continuous) group of the pill menu, then **Discrete**, so columns read November 2020, December 2020, January 2021. Plain MONTH() puts January before November, and YEAR() merges the months.
- Rows: Item Category, sorted descending by revenue. Mark type: **Square**. Colour and Label: Item Revenue Usd, Blue sequential palette.
- Hide the "Month of Month" header (right-click > Hide Field Labels for Columns).
- Title: "Item revenue by group and month".

### Opportunity worksheets

**Opportunity Range** (Opportunities source)
1. Set Extra Revenue 10Pct, 25Pct and 50Pct to Currency (Custom), 0 decimals. Create `Range Width` (section 2).
2. Rows: **Opportunity**. Columns: **Extra Revenue 10Pct**. The file also has Extra Conversions columns with near-identical names; using one of those makes every bar start near $0.
3. Mark type: **Gantt Bar**, Size: **Range Width**, colour light grey. This draws each range from the 10% to the 50% scenario.
4. Add **Extra Revenue 25Pct** to Columns, **Dual Axis**, **Synchronize Axis**, hide the top axis. On its tab: Circle, #2A78D6, Label Extra Revenue 25Pct, nothing on Size.
5. Sort Opportunity descending by Sum of Extra Revenue 25Pct. Axis: title "Extra revenue over the three months", currency format.
6. Title: "What closing part of each gap would be worth: dot = 25% of the gap, bar = 10% to 50%".

**Test Plan** (Test Plan source)
1. Convert **Gap Closed** and **Target Rate** to Dimension and Discrete. Formats: Gap Closed Percentage 0 decimals, Target Rate Percentage 1 decimal, Weeks At Current Traffic Number 1 decimal.
2. Rows: Gap Closed, Target Rate. Measure Names to Filters > **None** > Sessions Per Variant and Weeks At Current Traffic. Measure Names to Columns, Measure Values onto Text.
3. Aliases: "Sessions per variant" and "Weeks at this period's traffic".
4. Title: "A/B test size for the payment step (80% power, 5% significance, from a 48.4% baseline)".

## 4. Filters

Create filters on a worksheet, then show them on the dashboard (click a sheet on the dashboard > its down arrow > **Filters**).

**Sessions source** (create on Revenue by Week): drag each field to Filters, click **All** > OK, then right-click > **Apply to Worksheets > All Using This Data Source** > **Show Filter**, and set the card to **Single Value (dropdown)**.
- **Session Date**, choosing **Month / Year** in the first dialog.
- **Device**, **Visitor Type**, **Country Group**, **Channel**.

Then limit **Visitor Type**: right-click it > **Apply to Worksheets > Selected Worksheets** and untick Funnel Step Rates, Funnel Volume and Cart Abandonment. Filters applied to all sheets share one setting across pages, so without this, picking New on the Overview would remove the Returning bars from the funnel page.

**Products source** (create on Revenue by Group): **Item Category**, and **Month** as **Month / Year**, each applied to all sheets using the Products source.

The Attribution, Opportunities and Test Plan sheets cover the whole period and take no filters.

## 5. Dashboards

**Dashboard > New Dashboard** for each page. Size: **Fixed size, 1200 x 900** (Dashboard pane > Size). Use a **Vertical** container for the page and **Horizontal** containers for rows. Put a title text box at the top of every page with the same style, and the page's filters in one row under it.

**Overview**
- Title: "Google Merchandise Store: revenue and conversion, Nov 2020 to Jan 2021".
- Row 1: KPI Tiles.
- Row 2: Revenue by Week | Conversion by Week.
- Row 3: Conversion by Visitor Type | Conversion by Device.
- Text box: "Returning visitors convert at more than four times the rate of new ones. Mobile and desktop convert at the same rate: the gap is who the visitor is, not the device. Bars show 95% confidence intervals. Revenue is understated 1 to 10 November (purchases without transaction IDs are excluded) and from 26 January (purchases recorded without revenue); the last weekly point is a single day."

**Checkout Funnel**
- Filters: Month, Device, Channel, Country Group. No Visitor Type filter: this page compares the two.
- Row 1: Funnel Step Rates (wide). Set it to **Fit > Entire View** so all twelve bars show without scrolling.
- Row 2: Funnel Volume | Cart Abandonment.
- Text box: "Of new visitors who enter shipping details, 48% go on to enter payment details, against 83% of returning visitors. Once payment is entered, both complete at similar rates. A session counts at a step only if it completed every earlier step in that session; in this data the shipping step fires with the start of checkout, so it shows 100%."

**Channels**
- Filters: Month, Device, Visitor Type.
- Row 1: Channel Conversion | Channel Revenue.
- Row 2: Per Session vs First Touch.
- Text box: "Self-referral: visits that restarted on the store's own domain, often on return from checkout. They carry a third of revenue, but no outside site sent the visitor; fixing this in GA4 means listing the store's domains as unwanted referrals. A quarter of sessions have no recorded source and are left out. Per session, paid search converts at 0.61%; the visitors it first brought go on to buy at about the same rate as organic search's (1.27% vs 1.31%)."
- Note under Per Session vs First Touch: "Whole period; not affected by filters."

**Products**
- Filters: Item Category, Month.
- Row 1: Revenue by Group | Top Products.
- Row 2: Group by Month.
- Text box: "Purchases only. Apparel brings 58% of item revenue, and 13 of the top 15 products are apparel, led by hoodies and sweatshirts in the winter season. In this data, product-view and add-to-cart events carry long product lists (about 36 and 44 per session), so per-product view and add-to-cart rates are not reliable and are not shown."

**Opportunity**
- Row 1: Opportunity Range (wide).
- Row 2: Test Plan | text box with assumptions:
  "Each estimate closes part of a significant gap between new and returning visitors, valued at new visitors' revenue per conversion. The estimates overlap (a better payment step is part of better cart completion), so they are alternatives, not a total. Counted revenue in the period was $307,640. Returning visitors arrive with more intent, so closing the whole gap is not assumed. The data has no costs, so these are revenue, not profit. The test plan shows how many new visitors reaching shipping each version of the checkout needs before a change to the payment step can be judged."

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
- Selecting Visitor Type = New on the Overview changes every chart on the page, and the Checkout Funnel page still shows both visitor types.
- Not recorded never appears in the channel charts.
- No chart shows a rate as a SUM of rates (all rates come from the calculated fields).

## 7. Publish

1. **File > Save to Tableau Public As...**, sign in, and name the workbook "Google Merchandise Store Revenue and Conversion".
2. The published viz opens in the browser. Under its settings (the gear or "Edit Details"), add a description and set **Show views as tabs** on, so all five pages are reachable.
3. While you are still working on it, you can turn off **Show Viz on Profile**; turn it back on when finished.
4. Copy the viz's URL and send it to me for the README.
5. Screenshots: on each page, use **Download > Image** in Tableau Public (or Cmd+Shift+4 on the Mac) and save them as `images/dashboard_overview.png`, `images/dashboard_funnel.png`, `images/dashboard_channels.png`, `images/dashboard_products.png` and `images/dashboard_opportunity.png`. **Download > PDF** with "This workbook" selected saves all pages; move it into the project as `dashboards/revenue_conversion_dashboard.pdf`. Do not type the folder into the file name box of a Mac save dialog: macOS stores the slash as a colon, and Git will not find the file.
