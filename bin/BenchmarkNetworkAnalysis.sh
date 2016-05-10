#! /bin/bash
# Geoffrey Hannigan
# Pat Schloss Lab
# University of Michigan

# Run the perl script to create the benchmarking database
perl BenchmarkDatabaseCreation.pl \
	-i ../data/ValidationSet/FormatInteractions.tsv \
	-c ../data/BenchmarkingSet/BenchmarkCrisprsFormat.tsv \
	-b ../data/BenchmarkingSet/BenchmarkProphagesFormatFlip.tsv \
	-p ../data/BenchmarkingSet/PfamInteractionsFormatScoredFlip.tsv \
	-x ../data/BenchmarkingSet/MatchesByBlastxFormatOrder.tsv
