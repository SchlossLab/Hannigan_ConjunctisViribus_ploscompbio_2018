
cut -f 2 ./data/genbankPhageHost/viral_host_species.tsv \
	| sed 's/ /_/g' \
	| sort \
	| uniq \
	> ./data/genbankPhageHost/viral_host_only.tsv

# Clean before appending
rm ./data/genbankPhageHost/BacRef/bacteria.complete.species.refset.fa

while read p; do
	echo "^>.+$p"
	egrep -m 1 -A 1 "^>.+$p" ./data/genbankPhageHost/BacRef/bacteria.complete.species.fa >> ./data/genbankPhageHost/BacRef/bacteria.complete.species.refset.fa
done < ./data/genbankPhageHost/viral_host_only.tsv

# Create random contig fragments from the bacterial references and the viral references
percents=( 1 0.9 0.8 0.7 0.6 0.5 )
for i in "${percents[@]}"; do
	echo $i
	perl ./bin/RandomContigGenerator.pl -i ./data/genbankPhageHost/BacRef/bacteria.complete.species.refset.fa -o ./data/genbankPhageHost/BacRef/bacteria.fragment.${i}.fa -p $i
	perl ./bin/RandomContigGenerator.pl -i ./data/genbankPhageHost/VirRef/filtered.virus.fa -o ./data/genbankPhageHost/VirRef/virus.fragment.${i}.fa -p $i
	sed -i 's/[^>^A-Z^a-z^0-9]/_/g' ./data/genbankPhageHost/VirRef/virus.fragment.${i}.fa
done


percents=( 1 0.9 0.8 0.7 0.6 0.5 )
for i in "${percents[@]}"; do
	mkdir -p ./data/SecondaryBenchmarkingSet_${i}
	bash ./bin/BenchmarkingModel_SecondaryValidation.sh ./data/genbankPhageHost/VirRef/virus.fragment.${i}.fa ./data/genbankPhageHost/BacRef/bacteria.fragment.${i}.fa ./data/SecondaryBenchmarkingSet_${i}/BenchmarkCrisprsFormat_${i}.tsv ./data/SecondaryBenchmarkingSet_${i}/BenchmarkProphagesFormatFlip_${i}.tsv ./data/SecondaryBenchmarkingSet_${i}/MatchesByBlastxFormatOrder_${i}.tsv ./data/SecondaryBenchmarkingSet_${i}/PfamInteractionsFormatScoredFlip_${i}.tsv "SecondaryBenchmarkingSet_${i}"
done
