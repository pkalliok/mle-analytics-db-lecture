CREATE KEYSPACE foobar WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};
CREATE TABLE foobar.events (
	peer text,
	time text,
	address text,
	referrer text,
	PRIMARY KEY (peer, time, address)
);
