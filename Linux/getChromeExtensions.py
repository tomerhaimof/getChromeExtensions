#!/usr/bin/python

'''
This script will print all of the Google Chrome and Chromium extensions from all users
Written by Tomer Haimof
'''
import requests
import re
import os
import json
from requests.exceptions import ConnectionError
from threading import Thread


def checkExtension(result,folderName,extensionID,index,url,headers):
	try:
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
	except ConnectionError as e:
		print "There was an network connection error, please check you can reach https://chrome.google.com and try again"



### MAIN ###

excludes = ["pkedcjkdefgpdelpbcmbmeomcjbeemfm","nmmhkkegccagdldgiimedpiccmgmieda", ".DS_Store", "Temp"]

jsonData=""

url="https://chrome.google.com/webstore/detail/"
headers = {"accept-language": "en-US,en;q=0.9"}
users=os.listdir("/home")
users.append('root')
bold='\033[1m'
resetBold='\033[0m'

for i in users:
	baseDirs=[]
	if i=='root':
		if os.path.isfile("/root/.config/chromium/Local State"):
			baseDirs.append("/root/.config/chromium")
		if os.path.isfile("/root/.config/google-chrome/Local State"):
			baseDirs.append("/root/.config/google-chrome")
		if len(baseDirs) == 0:
			continue
	else:
		if os.path.isfile("/home/%s/.config/chromium/Local State" % (i)):
			baseDirs.append("/home/%s/.config/chromium" % (i))
		if os.path.isfile("/home/%s/.config/google-chrome/Local State" % (i)):
			baseDirs.append("/home/%s/.config/google-chrome" % (i))
		if len(baseDirs) == 0:
			continue
	for baseDir in baseDirs:
		baseDirSplit = baseDir.split("/")
		browser = baseDirSplit[len(baseDirSplit)-1]
		with open('%s/Local State' % (baseDir)) as json_file:
			jsonData=json.load(json_file)
		folders=os.listdir("%s" % (baseDir))
		for f in folders:
			if (f.startswith('Profile ') or f=="Default"):
				threads = []
				username=jsonData['profile']['info_cache'][f]['name']
				extensionsID=os.listdir("%s/%s/Extensions" % (baseDir,f))
				for e in excludes:
					if e in extensionsID:
						extensionsID.remove(e)
				result = {}
				print(bold + "\nPrinting extensions for user: " + i + "\\" + username + " (browser: " + browser +")" + resetBold)
				for x in range(len(extensionsID)):
					process = Thread(target=checkExtension, args=[result,f, extensionsID[x], x, url, headers])
					process.start()
					threads.append(process)
				for process in threads:
					process.join()

				
				for n in range(len(result)):
					print ("\t" +result[n]['folder'] + ":  " + result[n]['extension'] + ":  " + result[n]['name'])
