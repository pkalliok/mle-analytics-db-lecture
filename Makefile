
.PHONY: stop cqlsh cqlsh-2 logs

stop:
	docker-compose -f docker/cassandra-cluster.yml down

logs:
	docker-compose -f docker/cassandra-cluster.yml logs -f

stamps/cassandra-seed-up: docker/cassandra-cluster.yml 
	docker-compose -f $< up -d seed-cassandra
	touch $@

stamps/cassandra-wait: stamps/cassandra-seed-up
	until echo | nc localhost 19042 | grep -q 'protocol version'; do \
		echo -n .; sleep 2; done
	touch $@

stamps/cassandra-cluster-up: docker/cassandra-cluster.yml stamps/cassandra-wait
	docker-compose -f $< up -d cassandra-1 cassandra-2
	touch $@

stamps/cassandra-schema: cassandra/schema.cql stamps/cassandra-wait
	cat $< | docker-compose -f docker/cassandra-cluster.yml run cqlsh
	touch $@

stamps/cassandra-import: data/aineisto.csv stamps/cassandra-schema
	echo "COPY foobar.events (peer,time,address,referrer) FROM '/data/aineisto.csv';" \
	| docker run -i --rm --network docker_default -v `pwd`/data:/data \
		--name cassandra-import cassandra cqlsh seed-cassandra
	touch $@

cqlsh: stamps/cassandra-wait
	docker-compose -f docker/cassandra-cluster.yml run cqlsh

cqlsh-2: stamps/cassandra-cluster-up
	docker run -it --rm --network docker_default --name cqlsh-2 cassandra cqlsh cassandra-2

stamps/couchdb-seed-up: docker/couchdb-cluster.yml
	docker-compose -f $< up -d seed-couchdb
	touch $@

stamps/couchdb-wait: stamps/couchdb-seed-up
	until curl -s http://localhost:15984/ | grep -q '"couchdb":"Welcome"'; do \
		echo -n .; sleep 2; done
	touch $@

stamps/couchdb-import: data/aineisto.csv couchdb/set-up-database stamps/couchdb-wait
	./couchdb/set-up-database
	touch $@

