// OutlineGraphModel

// NODES
CREATE
	(study:Study {
		type : 'Study',
		projectid : 'Unique ID for the study',
		title : 'Paper title',
		doi: 'Paper DOI',
		year: 'Numeric Year',
		journal: 'Journal that published the paper',
		archivesystem: 'Code for sequence deposition archive',
		accession: 'Archive accession number'
	}),(sample:Sample {
		type : 'Sample',
		rawsampleid : 'Archival ID of the sample',
		studysampleid : 'Sample ID specific for the associated publicaiton',
		librarylayout : 'Paired end or other',
		librarysource : 'Metagneomic or other',
		platform : 'Platform used to sequence the sample',
		location : 'Area of subject from which sample was taken',
		seqnum : 'Total number of sequences in the sample'
	}),(subject:Subject {
		type : 'Subject',
		subjectid : 'Subject ID associated with the publication',
		sex : 'Subject sex',
		dob : 'Subject date of birth',
		smoker : 'Whether or not the subject is a smoker',
		source : 'What kind of organism the subject is'
	}),(phage:Phage{
		type : 'Phage',
		name : 'Name of the phage'
	}),(bacteria:Bacteria{
		type : 'Bacteria',
		name : 'Name of the bacterium',
		genus : 'Assigned genus name',
		species : 'Assigned species name',
		fullname : 'Name containing genus and species'
	}),(orf:ORF {
		type : 'Orf',
		orfid : 'Sample ID given to the ORF',
		annotation : 'ORF annotation'
	}),(disease:Disease {
		type : 'Disease',
		Name : 'Name of the disease'
	})

// Relationships
CREATE
	(study)-[:CohortContains]->(subject),
	(subject)-[:SequencesIn]->(sample),
	(sample)-[:SequencesPresent {
		sequencecount : 'number of sequences from sample matching organism'
		}]->(phage),
	(sample)-[:SequencesPresent {
		sequencecount : 'number of sequences from sample matching organism'
		}]->(bacteria),
	(phage)-[:Infects {
		crispr : 'Boolean for whether CRISPR targeting occurs', 
		blast : 'Blast score', 
		pfam : 'Pfam interaction domain score', 
		protasn : 'Protein association score'
		}]->(bacteria),
	(phage)-[:GenomeContains]->(orf),
	(bacteria)-[:GenomeContains]->(orf),
	(sample)-[:HealthStatus]->(disease)
