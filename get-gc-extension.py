#!/usr/bin/python

import requests
import re
import os
import json

def checkExtension(folderName,extensionID,url,headers):
	r = requests.get(url+extensionID, headers=headers)
	if r.status_code == 200:
		x=re.search("title\" content=\"(.*?)>", r.content)
		name=x.group(0).split("\"")[2]
		print(folderName + ":  " + extensionID + ":  " + name)
	elif r.status_code == 404 and extensionID not in excludes:
		print(folderName + ":  " + extensionID + ":  " + "UNKNOWN")




### MAIN ###



excludes = ["pkedcjkdefgpdelpbcmbmeomcjbeemfm","nmmhkkegccagdldgiimedpiccmgmieda",".DS_Store", "Temp"]
url="https://chrome.google.com/webstore/detail/"
headers = {"accept-language": "en-US,en;q=0.9"}
users=os.listdir("/Users")
for i in users:
	if os.path.isdir("/Users/%s/Library/Application Support/Google/Chrome/" % (i)):
		folders1=os.listdir("/Users/%s/Library/Application Support/Google/Chrome/" % (i))
		for f in folders1:
			if f.startswith('Profile ') or f=="Default":
				with open('/Users/%s/Library/Application Support/Google/Chrome/Local State' % (i)) as json_file:
					obj=json.load(json_file)
				username=obj['profile']['info_cache'][f]['name']
				extensions=os.listdir("/Users/%s/Library/Application Support/Google/Chrome/%s/Extensions" % (i,f))
				print("Printing extensions for user: " + i + "/" + username)
				for e in extensions:
					checkExtension(f,e,url,headers)
	'''
	if os.path.isdir("/Users/%s/Library/Application Support/Google/Chrome/Default/Extensions" % (i)):
		extensions=os.listdir("/Users/%s/Library/Application Support/Google/Chrome/Default/Extensions" % (i))
		print("Printing extensions for user: " + i)
		for e in extensions:
			checkExtension("Default",e,url,headers)
	'''

