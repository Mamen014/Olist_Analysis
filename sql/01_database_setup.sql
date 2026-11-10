-- Create raw SCHEMA
CREATE SCHEMA raw;

-- Create customer TABLE within raw SCHEMA
CREATE TABLE raw.customers (
	customer_id VARCHAR(32),
	customer_unique_id VARCHAR(32),
	customer_zipcode_prefix VARCHAR(5),
	customer_city TEXT,
	customer_state CHAR(2)
);

-- Create geolocation TABLE within raw SCHEMA
CREATE TABLE raw.geolocation(
	geolocation_zip_code_prefix CHAR(5),
	geolocation_lat DOUBLE PRECISION,
	geolocation_lng DOUBLE PRECISION,
	geolocation_city TEXT,
	geolocation_state CHAR(2)
);

-- Create order_items TABLE within raw SCHEMA
CREATE TABLE raw.order_items(
	order_id VARCHAR(32),
	order_item_id INTEGER,
	product_id VARCHAR(32),
	seller_id VARCHAR(32),
	shipping_limit_date TIMESTAMP,
	price NUMERIC(12,2),
	freight_value NUMERIC(12,2)
);

-- Create order_payments TABLE within raw SCHEMA
CREATE TABLE raw.order_payments(
	order_id VARCHAR(32),
	payment_sequential INTEGER,
	payment_type VARCHAR(30),
	payment_installments INTEGER,
	payment_value NUMERIC(12,2)
);

-- Create order_reviews TABLE within raw SCHEMA
CREATE TABLE raw.order_reviews(
	review_id VARCHAR(32),
	order_id VARCHAR(32),
	review_score INTEGER,
	review_comment_title TEXT,
	review_comment_message TEXT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP
);

-- Create orders TABLE within raw SCHEMA
CREATE TABLE raw.orders(
	order_id VARCHAR(32),
	customer_id VARCHAR(32),
	order_status VARCHAR(20),
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP
);

-- Create products TABLE within raw SCHEMA
CREATE TABLE raw.products(
	product_id VARCHAR(32),
	product_category_name TEXT,
	product_name_lenght INTEGER,
	product_description_lenght INTEGER,
	product_photos_qty INTEGER,
	product_weight_g INTEGER,
	product_length_cm INTEGER,
	product_height_cm INTEGER,
	product_width_cm INTEGER
);

-- Create sellers TABLE within raw SCHEMA
CREATE TABLE raw.sellers(
	seller_id VARCHAR(32),
	seller_zipcode_prefix CHAR(5),
	seller_city TEXT,
	seller_state CHAR(2)
);

-- Create category_name_translation TABLE within raw SCHEMA
CREATE TABLE raw.category_name_translation(
	product_category_name TEXT,
	product_category_name_english TEXT
);