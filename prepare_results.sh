./masters tsvall eil76 ./tsv_results/eil76_results.tsv
./masters tsvall a280 ./tsv_results/a280_results.tsv
./masters tsvall ali535 ./tsv_results/ali535_results.tsv
./masters tsvall rat783 ./tsv_results/rat783_results.tsv
./masters tsvall nrw1379 ./tsv_results/nrw1379_results.tsv

./masters tsvall xqf131 ./tsv_results/xqf131_results.tsv
./masters tsvall bcl380 ./tsv_results/bcl380_results.tsv

./masters div

python ./compile_results.py

echo "Number of results files:"
find ./results -type f | wc -l
