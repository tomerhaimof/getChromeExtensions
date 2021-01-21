#!/usr/bin/python

'''
This script will print all of the Google Chrome and Chromium extensions from all users
In addition, it will print all domains and IPs extracted from js,
    json,txt and html files inside extensions

Written by Tomer Haimof
'''
from __future__ import print_function
import re
import os
import json
from threading import Thread
from requests.exceptions import ConnectionError
import requests


#Some global variables

IP_REGEX_PATTERN = r"(((?<![\.0-9])[0-9]|(?<![\.0-9])([1-9][0-9])|(?<![\.0-9])(1[0-9]{2})|" \
    + r"(?<![\.0-9])(2[0-4][0-9]|25[0-5]))\.(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.)" \
    + r"{2}([0-9](?![\.0-9])|([1-9][0-9])(?![\.0-9])|(1[0-9]{2})(?![\.0-9])|(2[0-4][0-9])" \
    + r"(?![\.0-9])|(25[0-5])(?![\.0-9])))"
DOMAIN_REGEX_PATTERN = r"(https?:\/\/(([0-9a-zA-Z\-]?)*\.)+(com|il|net|io|me|org|nl" \
    + r"|cz|br|gov|il|ru|ir)\/[^\"^\{^\}^'^\(^\)^ ^>^\s]*[\"\{\}' \(\)>]{0})"
SAFESITES = ["google.com", "wikipedia.org", "w3.org", "googleapis.com", "mozilla.org",
             "microsoft.com", "jquery.com", "custom-cursor.com"]
BOLD = '\033[1m'
RESETBOLD = '\033[0m'
#Exclude trusted extensions: "Chrome Media Router"
EXCLUDES = ["pkedcjkdefgpdelpbcmbmeomcjbeemfm",
            ".DS_Store", "Temp"]

def get_files_from_path(path, files):
    '''
        add all files within "path" to "files" (list)
    '''
    file_extensions = ['.js', '.json', '.txt', '.html', '.md']
    for subdirs, dirs, files_ in os.walk(path):
        for file in files_:
            for ext in file_extensions:
                if file.endswith(ext):
                    files.append(os.path.join(subdirs, file))

def check_extension(result, folder_name, extension_id, index, url, headers, path, files, ips,
                    domains, filtered_domains):
    '''
        check the given extension
    '''
    try:
        res = requests.get(url+extension_id, headers=headers)

        if res.status_code == 200:
            found = re.search("title\" content=\"(.*?)>", res.content)
            name = found.group(0).split("\"")[2]
            result[index] = {"folder": folder_name, "extension": extension_id, 'name': name}
            #print(folder_name + ":  " + extension_id + ":  " + name)
        elif res.status_code == 404 and extension_id not in EXCLUDES:
            result[index] = {"folder": folder_name, "extension": extension_id, 'name': "UNKNOWN"}
            #print(folder_name + ":  " + extension_id + ":  " + "UNKNOWN")
        else:
            result[index] = {"folder": folder_name, "extension": extension_id, 'name': "ERROR"}
    except ConnectionError as err:
        print("There was a network connection error," \
             + "please verify https://chrome.google.com is reachable and try again")

    get_files_from_path(path, files)

    for file in files:
        #print file
        with open(file, 'r') as content_file:
            content = content_file.read()
            ip_ = set(re.findall(IP_REGEX_PATTERN, content))
            for _ip in ip_:
                ips.append(_ip[0])
                #print BOLD + _ip[0] + RESETBOLD + " " + file
            domain = set(re.findall(DOMAIN_REGEX_PATTERN, content))
            for _domain in domain:
                domain_safe = False
                for site in SAFESITES:
                    pattern = r"(https?:\/\/(([a-zA-Z0-9\-]*\.)*)?%s\/.*)" % site
                    if re.match(pattern, _domain[0]):
                        domain_safe = True
                if _domain[0].startswith("/") == False and domain_safe != True:
                    filtered_domains.append(_domain[0])
                    #print(BOLD + _domain[0].strip() + RESETBOLD + " " + file)
            result[index]['filtered_domains'] = filtered_domains 



### MAIN ###
def main():
    '''
        Main Function
    '''
    json_data = ""

    url = "https://chrome.google.com/webstore/detail/"
    headers = {"accept-language": "en-US,en;q=0.9"}
    users = os.listdir("/home")
    users.append('root')

    for i in users:
        base_dirs = []
        if i == 'root':
            if os.path.isfile("/root/.config/chromium/Local State"):
                base_dirs.append("/root/.config/chromium")
            if os.path.isfile("/root/.config/google-chrome/Local State"):
                base_dirs.append("/root/.config/google-chrome")
            if not base_dirs:
                continue
        else:
            if os.path.isfile("/home/%s/.config/chromium/Local State" % (i)):
                base_dirs.append("/home/%s/.config/chromium" % (i))
            if os.path.isfile("/home/%s/.config/google-chrome/Local State" % (i)):
                base_dirs.append("/home/%s/.config/google-chrome" % (i))
            if not base_dirs:
                continue
        for base_dir in base_dirs:
            base_dir_split = base_dir.split("/")
            browser = base_dir_split[len(base_dir_split)-1]
            with open('%s/Local State' % (base_dir)) as json_file:
                json_data = json.load(json_file)
            folders = os.listdir("%s" % (base_dir))
            for folder in folders:
                if (folder.startswith('Profile ') or folder == "Default"):
                    threads = []
                    username = json_data['profile']['info_cache'][folder]['name']
                    extensions_id = os.listdir("%s/%s/Extensions" % (base_dir, folder))
                    for ext in EXCLUDES:
                        if ext in extensions_id:
                            extensions_id.remove(ext)
                    result = {}
                    print(BOLD + "\n\nPrinting extensions for user: " + i + "\\" + username \
                        + " (browser: " + browser +")" + RESETBOLD)
                    for _ext in range(len(extensions_id)):
                        path = "%s/%s/Extensions/%s" % (base_dir, folder, extensions_id[_ext])
                        #print path
                        files = []
                        ips = []
                        domains = []
                        filtered_domains = []
                        process = Thread(target=check_extension,
                                         args=[result, folder, extensions_id[_ext], _ext, url,
                                               headers, path, files, ips, domains,
                                               filtered_domains])
                        process.start()
                        threads.append(process)
                    for process in threads:
                        process.join()

                    for n in range(len(result)):
                        print ("\n\t" + BOLD + result[n]['folder'] + ":  " \
                        	+ result[n]['extension'] + ":  " + result[n]['name'] + RESETBOLD)
                        if str(len(result[n]['filtered_domains'])) > "0":
                            print(BOLD + "\t\t" + "Printing all URLs found in extension's files" \
                             + "(except safe sites configured in the script):" + RESETBOLD)
                            for f in result[n]['filtered_domains']:
                                print("\t\t\t" + f)
                        if str(len(ips)) != "0":
                            print(BOLD + "\t\t" + "Printing all IPs found in extension's files:" \
                                 + RESETBOLD)
                            for _ip in ips:
                                print("\t\t\t" + _ip)



if __name__ == "__main__":
    main()
