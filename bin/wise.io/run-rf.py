#!/usr/bin/python

import sklearn
import numpy
import argparse
import pandas
from time import time
from PyWiseRF import WiseRF
from numpy import array

DESC="wise.io runner"
DEFAULT_NTREES = 100
DEFAULT_MTRY   = -1
DEFAULT_SAMPLE = 67
DEFAULT_PARSER_HEADER = True
DEFAULT_CPU_CORES=8

DATASETS_DIR='../../datasets'
WISE_IO_DIR='wise.io'


def log(msg):
    print msg

def main():
    parser = argparse.ArgumentParser(description=DESC)
    parser.add_argument('dataset', help="name of dataset", type=str)
    # Important parameters
    parser.add_argument('--ntrees', help="number of trees",type=int,default=DEFAULT_NTREES)
    parser.add_argument('--mtry', help="number of split features",type=int,default=DEFAULT_MTRY)
    parser.add_argument('--sample', help="sampling rate",type=int,default=DEFAULT_SAMPLE)
    parser.add_argument('--predictor', help="1-based column number to predict", required=True, type=int)
    # Tunning
    parser.add_argument('--parser_header', help="datasets contains header",type=bool,default=DEFAULT_PARSER_HEADER)
    parser.add_argument('--cpu_cores', help="number of CPU cores", type=int, default=DEFAULT_CPU_CORES)
    args = parser.parse_args()

    dataset_dir = "{0}/{1}".format(DATASETS_DIR, args.dataset)
    train_file  = "{0}/{1}/train.csv".format(dataset_dir,WISE_IO_DIR)
    test_file   = "{0}/{1}/test.csv".format(dataset_dir,WISE_IO_DIR)

    experiment(train_file, test_file, args.predictor, args.ntrees, args.mtry, args.sample, args.parser_header, args.cpu_cores )
    
def experiment(train_file, test_file, predictor, ntrees, mtry, sample, parser_header, cpu_cores):
    sample = sample / 100.0
    # Load train data
    trainDataX   = pandas.read_csv(train_file,header=0)
    predictorCol = trainDataX.columns[predictor]
    trainDataY   = array(trainDataX.pop(predictorCol), dtype=str)
    trainDataX   = array(trainDataX)

    timeTrainRF = time()
    rf          = WiseRF(n_estimators=ntrees, n_jobs=cpu_cores)
    rf.fit(trainDataX, trainDataY, debug=True)
    timeTrainRF = time() - timeTrainRF
            
    # Validation
    testDataX    = pandas.read_csv(test_file,header=0)
    predictorCol = testDataX.columns[predictor]
    testDataY    = array(testDataX.pop(predictorCol), dtype=str)
    testDataX    = array(testDataX)

    timeTestRF = time()
    predict    = rf.predict(array(testDataX))
    print predict
    testScore  = rf.score(testDataX,testDataY)
    timeTestRF = time() - timeTestRF
    print """
Train time: {0}
 Test time: {1}
 Err. rate: {2} %
{0},{1},{2}""".format(timeTrainRF, timeTestRF, 100*(1-testScore))


if __name__ == '__main__':
    main()
