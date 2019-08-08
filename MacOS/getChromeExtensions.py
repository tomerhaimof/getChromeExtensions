#!/usr/bin/python

import requests
import re
import os
import json
from threading import Thread


def checkExtension(result,folderName,extensionID,index,url,headers):
	r = requests.get(url+extensionID, headers=headers)

	if r.status_code == 200:
		x=re.search("title\" content=\"(.*?)>", r.content)
		name=x.group(0).split("\"")[2]
		result[index]={"folder": folderName,"extension": extensionID, 'name': name}
		#print(folderName + ":  " + extensionID + ":  " + name)
	elif r.status_code == 404 and extensionID not in excludes:
		result[index]={"folder": folderName,"extension": extensionID, 'name': "UNKNOWN"}
		#print(folderName + ":  " + extensionID + ":  " + "UNKNOWN")
	else:
		result[index]={"folder": folderName,"extension": extensionID, 'name': "ERROR"}



### MAIN ###

excludes = {"pkedcjkdefgpdelpbcmbmeomcjbeemfm","nmmhkkegccagdldgiimedpiccmgmieda", ".DS_Store"}

jsonData=""

url="https://chrome.google.com/webstore/detail/"
headers = {"accept-language": "en-US,en;q=0.9"}
users=os.listdir("/Users")
for i in users:
	if os.path.isdir("/Users/%s/Library/Application Support/Google/Chrome/" % (i)):
		with open('/Users/%s/Library/Application Support/Google/Chrome/Local State' % (i)) as json_file:
			jsonData=json.load(json_file)
		folders=os.listdir("/Users/%s/Library/Application Support/Google/Chrome/" % (i))
		for f in folders:
			if (f.startswith('Profile ') or f=="Default"):
				threads = []
				username=jsonData['profile']['info_cache'][f]['name']
				extensionsID=os.listdir("/Users/%s/Library/Application Support/Google/Chrome/%s/Extensions" % (i,f))
				for e in excludes:
					if e in extensionsID:
						extensionsID.remove(e)
				result = {}
				print("\nPrinting extensions for user: " + i + "\\" + username)
				for x in range(len(extensionsID)):
					process = Thread(target=checkExtension, args=[result,f, extensionsID[x], x, url, headers])
					process.start()
					threads.append(process)
				for process in threads:
					process.join()

				
				for n in range(len(result)):
					print (result[n]['folder'] + ":  " + result[n]['extension'] + ":  " + result[n]['name'])
						
	

