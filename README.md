# Script to upload lambda functions to AWS

Performs the management of configuring and uploading lambda functions according to documented and programmed use cases.


## Pseudo code

~~~
- Remove possible outdated related functions
- Read metadata
- Does function with the same name exist?

    NO:
    - Create new lambda function with all required configuration.

    YES:
    - Update metadata information
- Get identifier
- Add tags
~~~