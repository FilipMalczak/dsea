import csv, os, json

CSV_DIR = "./tsv_results"
SUMMARIES_DIR = "./summaries"
RAW_OUT = "raw.tsv"
SCALED_AVG_OUT = "scaled_avg.tsv"
SCALED_BEST_OUT = "scaled_best.tsv"

def dataset_name(csv_name):
    return csv_name.partition("_")[0]
    
SELECTS_TO_NAME = {
    ("Std=RankRoulette", "Harem=3=0.8=Tourney,5=Tourney,5=Tourney,5"): "DSEA (harem gender selection)",
    ("Std=RankRoulette", "NoGender=RankRoulette"): "DSEA (no gender, best operators)",
    ("Std=RankRoulette", "NoGender=Tourney,5"): "DSEA (no gender, different operators)",
    ("Std=Random", "Gender=Tourney,5=Tourney,5"): "SexualGA",
    ("Std=RankRoulette", "GGA=Random"): "GGA",
    ("Std=RankRoulette", "NoGender=Random"): "Plain GA (selection for survival)",
    ("Std=Random", "NoGender=Tourney,5"): "Plain GA (selection for breeding)"
}

BASELINE_SELECTS = ("Std=RankRoulette", "NoGender=Random")
BASELINE = SELECTS_TO_NAME[BASELINE_SELECTS]

RAW = "raw"
SCALED = "scaled"

AVG = "avg"
BEST = "best"

DATASET_ORDER = [
    "eil76",
    "xqf131",
    "a280",
    "bcl380",
    "ali535",
    "rat783",
    "nrw1379"
]

METHOD_ORDER = [
    "Plain GA (selection for survival)",
    "Plain GA (selection for breeding)",
    "GGA",
    "SexualGA",
    "DSEA (no gender, best operators)",
    "DSEA (no gender, different operators)",
    "DSEA (harem gender selection)"
]

def gather_results():
    out = {}
    for csv_name in os.listdir(CSV_DIR):
        dataset = dataset_name(csv_name)
        dataset_results = {}
        out[dataset] = {RAW: dataset_results}
        with open(os.path.join(CSV_DIR, csv_name)) as f:
            reader = csv.DictReader(f, delimiter="\t")
            for line in reader:
                natsel = line["natSel"]
                gensel = line["genSel"]
                selects = (natsel, gensel)
                method = SELECTS_TO_NAME[selects]
                dataset_results[method] = {
                    AVG: float(line["avgBest"]),
                    BEST: float(line["totalBest"])
                }
    return out

def scaled(raw_results):
    baseline_result = raw_results[BASELINE][AVG]
    out = {}
    for method, results in raw_results.iteritems():
        out[method] = {
            AVG: results[AVG]/baseline_result,
            BEST: results[BEST]/baseline_result
        }
    return out

def enhance_with_scaled(gathered):
    for dataset, results in gathered.iteritems():
        gathered[dataset][SCALED] = scaled(results[RAW])

def pprint(adict):
    print json.dumps(adict, sort_keys=True, indent=4, separators=(',', ': '))

def save_raw(results, f):
    writer = csv.DictWriter(f, fieldnames=["Dataset"] + METHOD_ORDER, delimiter="\t")
    writer.writeheader()
    for dataset in DATASET_ORDER:
        avg_row = {
            "Dataset": dataset+" ("+AVG+")"
        }
        best_row = {
            "Dataset": dataset+" ("+BEST+")"
        }
        for method in METHOD_ORDER:
            try:
                result = results[dataset][RAW][method]
                avg_row[method] = result[AVG]
                best_row[method] = result[BEST]
            except:
                avg_row[method] = "N/A"
                best_row[method] = "N/A"
        writer.writerow(avg_row)
        writer.writerow(best_row)

def save_scaled(results, f, avg_or_best):
    writer = csv.DictWriter(f, fieldnames=["Method"] + DATASET_ORDER, delimiter="\t")
    writer.writeheader()
    for method in METHOD_ORDER:
        row = {
            "Method": method
        }
        for dataset in DATASET_ORDER:
            try:
                row[dataset] = results[dataset][SCALED][method][avg_or_best]
            except:
                row[dataset] = "N/A"
        writer.writerow(row)


if __name__=="__main__":
    results = gather_results()
    enhance_with_scaled(results)
    with open(os.path.join(SUMMARIES_DIR, RAW_OUT), "w") as f:
        save_raw(results, f)
    with open(os.path.join(SUMMARIES_DIR, SCALED_AVG_OUT), "w") as f:
        save_scaled(results, f, AVG)
    with open(os.path.join(SUMMARIES_DIR, SCALED_BEST_OUT), "w") as f:
        save_scaled(results, f, BEST)
#    pprint(results)
