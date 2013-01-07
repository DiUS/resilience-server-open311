resilience-server-open311
=========================

An implementation of Open311's GeoReport v2 for Resilience. See http://wiki.open311.org/GeoReport_v2 for the specification.

Notes about this implementation:
* Only responses in JSON format are provided. XML is mandatory in the spec, while JSON is optional, but JSON is better for mobile clients.
* No services have metadata at the moment, so 'GET Service Definition' isn't supported.
* Multiple jurisdictions are not supported (optional in the spec).
* Tokens are not used (optional in the spec).
* Latitude and longitude are required when creating a service request.

Next steps:
* Run the Open311 validation tests against the implementation to confirm compliance.
* Add more stringent parameter checking.
* Add a PUT method so a service request's details or status can be changed.
* Implement the service discovery mechanism. See http://wiki.open311.org/Service_Discovery
* Add XML support.
