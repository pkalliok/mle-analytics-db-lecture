DIAGRAMS=db-dataflow bd-dataflow

.PHONY: stop cqlsh cqlsh-2 cas-logs cou-logs docs

docs: $(DIAGRAMS:%=diagrams/%.png)

stop:
	docker-compose -f cassandra/cassandra-cluster.yml down
	docker-compose -f couchdb/couchdb-cluster.yml down
	rm -f stamps/cassandra-seed-up stamps/couchdb-seed-up

data/cpi.csv:
	curl https://download.bls.gov/pub/time.series/cu/cu.data.0.Current \
	| sed 's#\([0-9]*\)\tM\([0-9]*\)#\1-\2-01#;s#[[:space:]]*$$##' > $@

data/us-census.zip:
	curl https://www2.census.gov/acs2013_1yr/summaryfile/2013_ACSSF_By_State_All_Tables/UnitedStates_All_Geographies.zip > $@

data/us-census: data/us-census.zip
	mkdir -p $@
	(cd $@ && unzip ../us-census.zip)

data/check_csv.py:
	curl https://raw.githubusercontent.com/pkalliok/csv-quality-checker/master/check_csv.py > $@

cas-logs:
	docker-compose -f cassandra/cassandra-cluster.yml logs -f

cou-logs:
	docker-compose -f couchdb/couchdb-cluster.yml logs -f

check-cpi: data/check_csv.py data/cpi.csv
	python $< -d '	' data/cpi.csv

data/aineisto_fixed.csv: data/fix_aineisto.py data/aineisto.csv
	python $< data/aineisto.csv > $@

check-aineisto: data/aineisto_fixed.csv data/check_csv.py
	wc -l $<
	python data/check_csv.py $<

stamps/cassandra-seed-up: cassandra/cassandra-cluster.yml
	docker-compose -f $< up -d seed-cassandra
	touch $@

stamps/cassandra-wait: stamps/cassandra-seed-up
	until echo | nc localhost 19042 | grep -q 'protocol version'; do \
		echo -n .; sleep 2; done
	touch $@

stamps/cassandra-cluster-up: cassandra/cassandra-cluster.yml stamps/cassandra-wait
	docker-compose -f $< up -d cassandra-1 cassandra-2
	touch $@

stamps/cassandra-schema: cassandra/schema.cql cassandra/cpi-schema.cql stamps/cassandra-wait
	cat $^ | docker-compose -f cassandra/cassandra-cluster.yml run cqlsh
	touch $@

stamps/cassandra-import-example: data/aineisto_fixed.csv stamps/cassandra-schema
	echo "COPY foobar.events (peer,time,address,referrer) FROM '/data/aineisto_fixed.csv';" \
	| docker run -i --rm --network cassandra_default -v `pwd`/data:/data \
		--name cassandra-import cassandra cqlsh seed-cassandra
	touch $@

stamps/cassandra-import-cpi: data/cpi.csv stamps/cassandra-schema
	echo "copy cpi.price from '/data/cpi.csv' with DELIMITER='\\t';" \
	| docker run -i --rm --network cassandra_default -v `pwd`/data:/data \
		--name cassandra-import cassandra cqlsh seed-cassandra

cqlsh: stamps/cassandra-wait
	docker-compose -f cassandra/cassandra-cluster.yml run cqlsh

cqlsh-2: stamps/cassandra-cluster-up
	docker run -it --rm --network cassandra_default --name cqlsh-2 cassandra cqlsh cassandra-2

stamps/couchdb-seed-up: couchdb/couchdb-cluster.yml
	docker-compose -f $< up -d seed-couchdb
	touch $@

stamps/couchdb-wait: stamps/couchdb-seed-up
	until curl -s http://localhost:15984/ | grep -q '"couchdb":"Welcome"'; do \
		echo -n .; sleep 2; done
	touch $@

stamps/couchdb-import: data/aineisto.csv couchdb/set-up-database stamps/couchdb-wait
	./couchdb/set-up-database
	touch $@

stamps/couchdb-cluster-up: couchdb/couchdb-cluster.yml couchdb/set-up-replication stamps/couchdb-import
	docker-compose -f $< up -d replicate-couchdb
	./couchdb/set-up-replication
	touch $@

%.png: %.dot
	dot -Tpng -o $@ $<

