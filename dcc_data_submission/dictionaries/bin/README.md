## Utility scripts for maintaining ICGC DCC "data dictionary"

The ICGC DCC's web-based data submission/validation system relied on input file specifications defined in a monolith JSON document referred to as the "data dictionary".
These utility scripts were written to simplify the maintenance of the DCC data specifications as non-redundant data element/data file templates,
and to instantiate these templates into the monolithic dictionary JSON file required by the software.

##### build_data_element_json.pl
Script to allow quick building of JSON document for an ICGC DCC data element from the command line.

##### create_final.sh
Provided a versioned dictionary template directory as input, runs 'file_template_to_json.pl' and 'json_files_to_json_dictionary.pl' to generate a dictionary JSON file compatible with the ICGC DCC data submission system. See versioned dictionary template directories under '../templates'.
Eg:
  ./create_final.sh dev [dictionary.dev.json]
  
##### file_template_to_json.pl
Processes a JSON template file supporting includes with special key '_include', and extending via '_extend'.

##### get_all_codelists.pl
Very quickly-written script to pull data element "codelists" from the ICGC DCC data submission system's REST API.

##### get_dictionaries.pl
Very quickly-written script to pull "data dicitionary" JSON from the ICGC DCC data submission system's REST API.

##### get_dictionary_codelists.pl
Presumably a more specific application than 'get_all_codelists.pl'; can't recall why two scripts exist, possibly result of changes to the system's REST API during development.

##### json_dictionary_to_json_files.pl
Splits a monolithic JSON dictionary file retrieved from the submission system into one JSON file per submission file type.

##### json_files_to_json_dictionary.pl
Joins individual file-type-based JSON files into a monolithic dictionary JSON file.
