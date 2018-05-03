CREATE KEYSPACE cpi WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};
CREATE TABLE cpi.price (
	cat_code text,
	time date,
	value double,
	PRIMARY KEY (cat_code, time)
);
