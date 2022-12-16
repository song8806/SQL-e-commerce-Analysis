-- 1. Monthly trends for gsearch and orders to show growth.

SELECT
    year(website_sessions.created_at),
    month(website_sessions.created_at),
    count(distinct website_sessions.website_session_id) as sessions,
    count(distinct orders.order_id) as orders, 
    count(distinct orders.order_id)/count(distinct website_sessions.website_session_id) as rate
FROM website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.utm_source = 'gsearch'
AND website_sessions.created_at < '2012-11-27' 
GROUP BY 1, 2;

-- 2. Splitting on nonbrand and brand

SELECT 
	year(website_sessions.created_at) as year,
    month(website_sessions.created_at) as month,
	count(website_sessions.website_session_id) sessions,
	count(distinct case when website_sessions.utm_campaign = 'nonbrand' then website_sessions.website_session_id else null end) as nonbrand_sessions,
    count(distinct case when website_sessions.utm_campaign = 'brand' then website_sessions.website_session_id else null end) as brand_sessions,
    count(distinct case when website_sessions.utm_campaign = 'brand' then orders.order_id else null end) as brand_orders
FROM website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.utm_source = 'gsearch'
AND website_sessions.created_at < '2012-11-27' 
GROUP BY 1, 2

  -- 3. Dive into nonbrand, pull monthly sessions and orders split by device type?
  
  SELECT
	year(website_sessions.created_at) as year,
    month(website_sessions.created_at) as month,
	count(website_sessions.website_session_id) sessions,
	count(distinct case when website_sessions.utm_campaign = 'nonbrand' then website_sessions.website_session_id else null end) as nonbrand_sessions,
    count(distinct case when website_sessions.utm_campaign = 'nonbrand' then orders.order_id else null end) as nonbrand_orders,
    count(distinct case when device_type = 'desktop' then website_sessions.website_session_id else null end) as desktop_sessions,
    count(distinct case when device_type = 'desktop' then orders.order_id else null end) as desktop_orders,
	count(distinct case when device_type = 'mobile' then website_sessions.website_session_id else null end) as mobile_sessions,
	count(distinct case when device_type = 'mobile' then orders.order_id else null end) as mobile_orders
FROM website_sessions 
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.utm_source = 'gsearch'
AND website_sessions.created_at < '2012-11-27' 
GROUP BY 1, 2;

-- 4. Monthly trend for gsearch and each of other channels?
-- first find various utm sources and referers

SELECT DISTINCT
	utm_source,
    utm_campaign,
    http_referer
FROM website_sessions
WHERE created_at < '2012-11-27';


SELECT 
	year(created_at) as year,
	month(created_at) as month,
	count(case when utm_source = 'gsearch' then website_session_id else null end) as gsearch_sessions,
	count(case when utm_source = 'bsearch' then website_session_id else null end) as bsearch_sessions,
	count(case when utm_source is null and utm_campaign is null and http_referer is null then website_session_id else null end) as direct_type_in_sessions,
	count(case when utm_source is null and utm_campaign is null and http_referer is not null then website_session_id else null end) as organic_search_sessions
FROM website_sessions
WHERE created_at < '2012-11-27' 
GROUP BY 1, 2
*/
-- 5. sessions to order conversion rates by months

SELECT 
	year(website_sessions.created_at) as year,
	month(website_sessions.created_at) as month,
    count(distinct website_sessions.website_session_id) as sessions,
    count(distinct orders.order_id) as orders,
	count(distinct orders.order_id)/count(distinct website_sessions.website_session_id) as conversion_rt
FROM website_sessions
LEFT JOIN orders ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2012-11-27' 
GROUP BY 1, 2;

 -- 6. For gsearch lander test, estimate revenue that tst earned us (increase in CVR from the test 6/19-7/28) 
 -- and use nonbrand sessions and revenue since then to calculate incremental values. 
 -- first, find first instance of lander-1 test: 6/19, pv_id = 23504
 
 SELECT
    created_at,
	min(website_pageview_id) as pv_id
 FROM website_pageviews
 WHERE pageview_url = '/lander-1'
 GROUP BY 1;
 
 -- find revenue for gsearch, lander between 6/19 and 7/28
 
 DROP TEMPORARY TABLE IF EXISTS first_test_pageviews;
 CREATE TEMPORARY TABLE first_test_pageviews
 SELECT
	website_pageviews.website_session_id,
    min(website_pageviews.website_pageview_id) as pv_id
FROM website_pageviews
INNER JOIN website_sessions ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.created_at < '2012-07-28'
AND website_pageviews.website_pageview_id >= 23504
AND website_sessions.utm_source = 'gsearch'
AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY 1;

-- get pageview_url

DROP TEMPORARY TABLE IF EXISTS first_pageview_url;
CREATE TEMPORARY TABLE first_pageview_url
SELECT
	first_test_pageviews.website_session_id,
	website_pageviews.pageview_url as landing_page	
FROM first_test_pageviews
LEFT JOIN website_pageviews ON first_test_pageviews.pv_id = website_pageviews.website_pageview_id
WHERE website_pageviews.pageview_url IN ('/home', '/lander-1')
GROUP BY 1;

DROP TEMPORARY TABLE IF EXISTS pageview_w_orders;
CREATE TEMPORARY TABLE pageview_w_orders
SELECT
	first_pageview_url.website_session_id,
	first_pageview_url.landing_page,
	orders.order_id as order_id
FROM first_pageview_url
LEFT JOIN orders ON first_pageview_url.website_session_id = orders.website_session_id;

SELECT
	landing_page,
	count(distinct website_session_id) as sessions,
    count(distinct order_id) as session_orders,
    count(distinct order_id)/count(distinct website_session_id) as convt_rt    
FROM pageview_w_orders
GROUP BY 1;

-- lander-1:0.0406, home:0.0318 ==> 0.0087 additional per session
-- finding the most recent pageview for gsearch and nonbrand where the traffic sent to /home.
-- because after the most recent date, all the website sessions will be changed to lander-1 
-- which performs better.

SELECT
	max(website_sessions.website_session_id) as most_recent_home -- 17145
FROM website_sessions
LEFT JOIN website_pageviews ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
AND utm_source = 'gsearch'
AND utm_campaign = 'nonbrand'
AND website_pageviews.pageview_url = '/home';

-- After the test is over, the business knows the new test page is better so will now shift 
-- ALL of the traffic to this page. This is why we use the total sessions to calculate 
-- how much the new page is worth to the business on a go forward basis.

SELECT
count(website_session_id) as sessions_since_test   -- 22,972
FROM website_sessions
WHERE website_sessions.created_at < '2012-11-27'
AND utm_source = 'gsearch'
AND utm_campaign = 'nonbrand'
AND website_session_id > 17145;

-- 22,972 x 0.087 incremental conversion = 202 for 4 months. about 50 extra orders per month.

-- 7. Full conversion funnel from home and lander-1 to orders (6/19 - 7/28)
-- find all relevant pageviews

CREATE TEMPORARY TABLE landing_funnels
SELECT
	website_sessions.website_session_id, 
    website_pageviews.pageview_url, 
    case when pageview_url = '/home' then 1 else 0 end as home_land,
    case when pageview_url = '/lander-1' then 1 else 0 end as lander_land,
    case when pageview_url = '/products' then 1 else 0 end as product_land,
    case when pageview_url = '/the-original-mr-fuzzy' then 1 else 0 end as mrfuzzy_land,
    case when pageview_url = '/cart' then 1 else 0 end as cart_land,
    case when pageview_url = '/shipping' then 1 else 0 end as shipping_land,
    case when pageview_url = '/billing' then 1 else 0 end as billing_land,
    case when pageview_url = '/thank-you-for-your-order' then 1 else 0 end as thankyou_land
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch' 
	AND website_sessions.utm_campaign = 'nonbrand' 
    AND website_sessions.created_at < '2012-07-28'
		AND website_sessions.created_at > '2012-06-19'
ORDER BY 
	website_sessions.website_session_id,
    website_pageviews.created_at;

CREATE TEMPORARY TABLE session_level_made_it_flagged
SELECT 
	website_session_id,
    max(home_land) as saw_homepage,
    max(lander_land) as saw_customer_lander,
    max(product_land) as to_product,
    max(mrfuzzy_land) as to_mrfuzzy,
    max(cart_land) as to_cart,
    max(shipping_land) as to_shipping,
    max(billing_land) as to_billing,
    max(thankyou_land) as to_thankyou
FROM landing_funnels
GROUP BY 1;

SELECT
	case 
		when saw_homepage = 1 then 'saw_homepage'
		when saw_customer_lander = 1 then 'saw_customer_lander'
		else 'check_logic' 
    end as segment,
	count(distinct website_session_id) as sessions,
    count(distinct case when to_product = 1 then website_session_id else null end) as product_made_it,
    count(distinct case when to_mrfuzzy = 1 then website_session_id else null end) as mrfuzzy_made_it,
    count(distinct case when to_cart = 1 then website_session_id else null end) as cart_made_it,
    count(distinct case when to_shipping = 1 then website_session_id else null end) as shipping_made_it,
    count(distinct case when to_billing = 1 then website_session_id else null end) as billing_made_it,
    count(distinct case when to_thankyou = 1 then website_session_id else null end) as thankyou_made_it
FROM session_level_made_it_flagged
GROUP BY 1;

SELECT
	case 
		when saw_homepage = 1 then 'saw_homepage'
		when saw_customer_lander = 1 then 'saw_customer_lander'
		else 'check_logic' 
    end as segment,
	count(distinct website_session_id) as sessions,
    count(distinct case when to_product = 1 then website_session_id else null end)/count(distinct website_session_id) as lander_click_rt,
    count(distinct case when to_mrfuzzy = 1 then website_session_id else null end)/count(distinct case when to_product = 1 then website_session_id else null end) as product_click_rt,
    count(distinct case when to_cart = 1 then website_session_id else null end)/count(distinct case when to_mrfuzzy = 1 then website_session_id else null end) as mrfuzzy_click_rt,
    count(distinct case when to_shipping = 1 then website_session_id else null end)/count(distinct case when to_cart = 1 then website_session_id else null end) as cart_click_rt,
    count(distinct case when to_billing = 1 then website_session_id else null end)/count(distinct case when to_shipping = 1 then website_session_id else null end) as shipping_click_rt,
    count(distinct case when to_thankyou = 1 then website_session_id else null end)/count(distinct case when to_billing = 1 then website_session_id else null end) as billing_click_rt
FROM session_level_made_it_flagged
GROUP BY 1;

    
  -- 8. Impact of billing test, analyze the lift of billing test generated from the test (9/10-11/10). Revenue per billing page session, 
  -- and then pull the number of billing page sessions for the past month to understand the monthly impact.
 
 CREATE TEMPORARY TABLE billing_orders
 SELECT 
	website_pageviews.website_session_id,
    website_pageviews.pageview_url as billing_page_seen,
    orders.order_id,
    orders.price_usd
FROM website_pageviews
LEFT JOIN orders ON website_pageviews.website_session_id = orders.website_session_id
WHERE website_pageviews.created_at > '2012-09-10'
AND website_pageviews.created_at < '2012-11-10'
AND pageview_url in ('/billing', '/billing-2')

SELECT
	billing_page_seen, 
    count(distinct website_session_id) as sessions,
    count(case when order_id is not null then order_id else null end) as orders,
    sum(price_usd)/count(distinct website_session_id) as revenue_per_billing_page_seen
FROM billing_orders
GROUP BY 1;

-- $8.51 lift
SELECT
	billing_page_seen, 
    count(distinct website_session_id) as sessions,
    count(distinct order_id) as orders,
    count(distinct order_id)/count(distinct website_session_id) as conv_rt
FROM billing_orders
GROUP BY 1;

SELECT
	count(distinct website_session_id) as billing_session_past_month
FROM website_pageviews
WHERE created_at between '2012-10-27' and '2012-11-27'
AND pageview_url in ('/billing', '/billing-2');
