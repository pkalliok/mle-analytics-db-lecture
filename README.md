# mle-analytics-db-lecture

Analytics databases lecture for the MLE course

## Things to try

Most automations are written as "stamp" rules in the [./Makefile].

 * get a cqlsh to Cassandra: `make cqlsh`
 * import data to Cassandra: `make stamps/cassandra-import-example`
 * set up a Cassandra cluster: `make stamps/cassandra-cluster-up`

Similar targets exist for Couchdb, too.

 * run an automatic CSV quality checker on the input files: `make check-aineisto` and `make check-cpi`

