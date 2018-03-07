from Bio import SeqIO
import re
import argparse

# Create argparser
parser = argparse.ArgumentParser(description='Parse GenBank files for phage-host interactions.')
parser.add_argument(
	"-i",
	dest="input",
	required=True,
	help="Input file with two matrices",
	metavar="FILE")
parser.add_argument(
	"-o",
	dest="output",
	required=True,
	help="Output file with two matrices",
	metavar="FILE")
args = parser.parse_args()

# Open output file for writing
outfile = open(args.output, 'w')

for index, record in enumerate(SeqIO.parse(args.input, "genbank")):
	for ind, feature in enumerate(record.features):
		if feature.type=="source" :
			if 'organism' in feature.qualifiers :
				if 'host' in feature.qualifiers :
					regexp = re.compile(r'[Pp]hage')
					word = str(feature.qualifiers['organism'])
					if regexp.search(word) :
						orgvar = ''.join(feature.qualifiers['organism'])
						hostvar = ''.join(feature.qualifiers['host'])
						outfile.write(orgvar + "\t" + hostvar + "\n")

outfile.close()
