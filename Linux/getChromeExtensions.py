#!/usr/bin/python

'''
This script will print all of the Google Chrome and Chromium extensions from all users
In addition, it will print all domains and IPs extracted from js, json,txt and html files inside extensions
Written by Tomer Haimof
'''
import requests
import re
import os
import json
from requests.exceptions import ConnectionError
from threading import Thread


#Some global variables

IP_REGEX_PATTERN="(((?<![\.0-9])[0-9]|(?<![\.0-9])([1-9][0-9])|(?<![\.0-9])(1[0-9]{2})|(?<![\.0-9])(2[0-4][0-9]|25[0-5]))\.(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}([0-9](?![\.0-9])|([1-9][0-9])(?![\.0-9])|(1[0-9]{2})(?![\.0-9])|(2[0-4][0-9])(?![\.0-9])|(25[0-5])(?![\.0-9])))"
DOMAIN_REGEX_PATTERN="(https?:\/\/(([0-9a-zA-Z\-]?)*\.)+(com|il|net|io|me|org|nl|cz|br|gov|il|ru|ir)\/[^\"^\{^\}^'^\(^\)^ ^>^\s]*[\"\{\}' \(\)>]{0})"
SAFESITES = ["google.com","wikipedia.org","w3.org","googleapis.com","mozilla.org","microsoft.com","jquery.com","custom-cursor.com"]
BOLD='\033[1m'
RESETBOLD='\033[0m'

def extractDomainsAndIPs(path,files):
	for r, d, f in os.walk(path):
		for file in f:
			if file.endswith('.js') or file.endswith('.json') or file.endswith('.txt') or file.endswith('.html'):
				files.append(os.path.join(r, file))

def checkExtension(result,folderName,extensionID,index,url,headers,path,files,ips,domains,filteredDomains):
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
	
	extractDomainsAndIPs(path,files)
		
	for file in files:
		#print file
		with open(file, 'r') as content_file:
			content = content_file.read()
			ip=set(re.findall(IP_REGEX_PATTERN, content))
			for _ip in ip:
				ips.append(_ip[0])
				#print BOLD + _ip[0] + RESETBOLD + " " + file
			domain=set(re.findall(DOMAIN_REGEX_PATTERN,content))
			for _domain in domain:
				domainSafe=False
				for s in SAFESITES:
					pattern="(https?:\/\/(([a-zA-Z0-9\-]*\.)*)?%s\/.*)" % s
					if re.match(pattern,_domain[0]):
						domainSafe=True
				if _domain[0].startswith("/") == False and domainSafe != True:
					filteredDomains.append(_domain[0])
					#print BOLD + _domain[0].strip() + RESETBOLD + " " + file



### MAIN ###
def main():
	excludes = ["pkedcjkdefgpdelpbcmbmeomcjbeemfm","nmmhkkegccagdldgiimedpiccmgmieda", ".DS_Store", "Temp"]
	
	jsonData=""

	url="https://chrome.google.com/webstore/detail/"
	headers = {"accept-language": "en-US,en;q=0.9"}
	users=os.listdir("/home")
	users.append('root')

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
					print(BOLD + "\n\nPrinting extensions for user: " + i + "\\" + username + " (browser: " + browser +")" + RESETBOLD)
					for x in range(len(extensionsID)):
						path="%s/%s/Extensions/%s" % (baseDir,f, extensionsID[x])
						#print path
						files=[]
						ips=[]
						domains=[]
						filteredDomains=[]
						process = Thread(target=checkExtension, args=[result,f, extensionsID[x], x, url, headers, path,files,ips,domains,filteredDomains])
						process.start()
						threads.append(process)
					for process in threads:
						process.join()

					
					for n in range(len(result)):
						print ("\n\t" + BOLD + result[n]['folder'] + ":  " + result[n]['extension'] + ":  " + result[n]['name']) + RESETBOLD
						if str(len(filteredDomains)) > "0":
							print BOLD + "\t\t" + "Printing all domains found in extension's files (except safe sites configured in the script):" + RESETBOLD
							for f in filteredDomains:
								print "\t\t\t" + f
						if str(len(ips)) != "0":
							print BOLD + "\t\t" + "Printing all IPs found in extension's files:" + RESETBOLD
							for i in ips:
								print "\t\t\t" + i



if __name__=="__main__":
	main()
