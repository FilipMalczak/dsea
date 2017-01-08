./masters csvall eil76 ./csv_results/eil76_results.csv
./masters csvall a280 ./csv_results/a280_results.csv
./masters csvall ali535 ./csv_results/ali535_results.csv
./masters csvall rat783 ./csv_results/rat783_results.csv
./masters csvall nrw1379 ./csv_results/nrw1379_results.csv

./masters csvall xqf131 ./csv_results/xqf131_results.csv
./masters csvall bcl380 ./csv_results/bcl380_results.csv

echo "Number of results files:"
find ./results -type f | wc -l
