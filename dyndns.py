#!/usr/bin/python
#
# Easy Python3 Dynamic DNS
# By Jed Smith <jed@jedsmith.org> 4/29/2009
# This code and associated documentation is released into the public domain.
#
# Modified by Jason Blevins <jrblevin@sdf.org> 7/13/2013
#
# To use:
#
#   0. You'll probably have to edit the shebang above.
#
#   1. In the Linode DNS manager, edit your zone (must be master) and create
#      an A record for your home computer.  You can name it whatever you like;
#      I call mine 'home'.  Fill in 0.0.0.0 for the IP.
#
#   2. Save it.
#
#   3. Go back and edit the A record you just created. Make a note of the
#      ResourceID in the URI of the page while editing the record.
#
#   4. Edit the four configuration options below, following the directions for
#      each.  As this is a quick hack, it assumes everything goes right.
#
# First, the resource ID that contains the 'home' record you created above. If
# the URI while editing that A record looks like this:
#
#  linode.com/members/dns/resource_aud.cfm?DomainID=98765&ResourceID=123456
#
# The URI of a Web service that returns your IP address as plaintext.  You are
# welcome to leave this at the default value and use mine.  If you want to run
# your own, the source code of that script is:
#
#     <?php
#     header("Content-type: text/plain");
#     printf("%s", $_SERVER["REMOTE_ADDR"]);
#
#GETIP = "http://hosted.jedsmith.org/ip.php"
GETIP = "https://wtfismyip.com/text"
#
# If for some reason the API URI changes, or you wish to send requests to a
# different URI for debugging reasons, edit this.  {0} will be replaced with the
# API key set above, and & will be added automatically for parameters.
#
API = "https://api.linode.com/api/?api_key={0}&resultFormat=JSON"
#
# That's it!
#
# Now run dyndns.py manually, or add it to cron, or whatever.  You can even have
# multiple copies of the script doing different zones.
#
# For automated processing, this script will always print EXACTLY one line, and
# will also communicate via a return code.  The return codes are:
#
#    0 - No need to update, A record matches my public IP
#    1 - Updated record
#    2 - Some kind of error or exception occurred
#
# The script will also output one line that starts with either OK or FAIL.  If
# an update was necessary, OK will have extra information after it.

import argparse
from json import load
from urllib import urlencode, urlretrieve

def execute(key, action, parameters):
	# Execute a query and return a Python dictionary.
	uri = "{0}&action={1}".format(API.format(key), action)
	if parameters and len(parameters) > 0:
		uri = "{0}&{1}".format(uri, urlencode(parameters))
	file, headers = urlretrieve(uri)
	json = load(open(file), encoding="utf-8")
	if len(json["ERRORARRAY"]) > 0:
		err = json["ERRORARRAY"][0]
		raise Exception("Error {0}: {1}".format(int(err["ERRORCODE"]),
			err["ERRORMESSAGE"]))
	return load(open(file), encoding="utf-8")

def ip():
	file, headers = urlretrieve(GETIP)
	return open(file).read().strip()

def main():
        desc = "This script is a Dynamic DNS updater for Linode."

        parser = argparse.ArgumentParser(description=desc)
        parser.add_argument('-d', action='store', dest='domain_id',
                            required=True, help='domain ID number')
        parser.add_argument('-r', action='store', dest='resource_id',
                            required=True, help='resource ID number')
        parser.add_argument('-k', action='store', dest='apikey',
                            required=True, help='API key')
        results = parser.parse_args()

	try:
                request = {
                        "DomainID": results.domain_id,
                        "ResourceID": results.resource_id
                }
		res = execute(results.apikey, "domain.resource.list", request)["DATA"][0]
		if (len(res)) == 0:
			raise Exception("No such resource?".format(RESOURCE))
		public = ip()
		if res["TARGET"] != public:
			old = res["TARGET"]
			request = {
				"ResourceID": res["RESOURCEID"],
				"DomainID": res["DOMAINID"],
				"Name": res["NAME"],
				"Type": res["TYPE"],
				"Target": public,
				"TTL_Sec": res["TTL_SEC"]
			}
			execute(results.apikey, "domain.resource.update", request)
			print "OK {0} -> {1}".format(old, public)
			return 1
		else:
			print "OK"
			return 0
	except Exception as excp:
		print "FAIL {0}: {1}".format(type(excp).__name__, excp)
		return 2

if __name__ == "__main__":
	exit(main())
