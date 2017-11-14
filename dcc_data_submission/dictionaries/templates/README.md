Explanation of Dictionary Templates
===================================

For reasons lost to time the ICGC DCC data specifications, as implemented in the BioMart-based DCC 1.0, were defined and maintained as Excel spreadsheets.

In developing the DCC 2.0's data submission/validation system, these essentially flat-file format definitions were merged into a monolithic JSON document that described the accepted data submission file format and the validation rules that were to be applied to each data element.

The unfortunate consequence of duplication of common data element definitions across the different data file types was duplication within the JSON document (referred to as the "data dictionary" in the context of the data submission system).

To improve the maintainability of the data specification, I broke the dictionary down into the unique set of common (global) and file-type specific data element definitions, and then built templates that referenced these common element definitions via include.

See '../bin/create_final.sh' for how these templates were processed to recreate the 'final' dictionary JSON format supported by the submission system.
