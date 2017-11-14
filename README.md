icgc-dcmwg
==========

The code in this repo was written by Brett Whitty during the transition from the first iteration BioMart-based ICGC DCC data portal to the current ICGC DCC data portal; most was quickly put together to allow production use of the under-development web-based data submission/validation system developed as part of the "DCC 2.0" portal.

The code under 'dictionaries' was used to manage the conversion/maintenance of the ICGC DCC data specifications and encode them into the JSON format developed for the DCC's web-based data submission system.

The code under 'tools' is various utility scripts, including 'auto_submit.pl' which provided a command-line interface for the submission system's REST API, allowing data upload, validation, querying status, etc. This was developed initially for my own testing purposes, but was subsequently used by OICR's production sequencing group for automating data submissions (shortly after this repo went live).
