#!/usr/bin/python3

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
import sys
from requests.exceptions import ConnectionError
import requests

# Some global variables
IP_REGEX_PATTERN = r"(((?<![\.0-9])[0-9]|(?<![\.0-9])([1-9][0-9])|(?<![\.0-9])(1[0-9]{2})|" \
    + r"(?<![\.0-9])(2[0-4][0-9]|25[0-5]))\.(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.)" \
    + r"{2}([0-9](?![\.0-9])|([1-9][0-9])(?![\.0-9])|(1[0-9]{2})(?![\.0-9])|(2[0-4][0-9])" \
    + r"(?![\.0-9])|(25[0-5])(?![\.0-9])))"
DOMAIN_REGEX_PATTERN = r"(https?:\/\/(([0-9a-zA-Z\-]?)*\.)+(aero|asia|biz|cat|com|coop|edu|gov|" \
 + "info|int|jobs|mil|mobi|museum|name|net|org|pro|tel|travel|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|" \
 + "ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bl|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|" \
 + "cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cu|cv|cx|cy|cz|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi" \
 + "|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|" \
 + "hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|" \
 + "li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my" \
 + "|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|" \
 + "qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|sk|sl|sm|sn|so|sr|st|su|sv|sy|sz|tc|td|tf|" \
 + "tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|um|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws" \
 + r"|ye|yt|yu|za|zm|zw)\/[^\"^\{^\}^'^\(^\)^ ^>^\s^\*^<^>^\\\,]*[\,\"\{\}' \(\)>]{0})"
SAFESITES = ["google.com", "wikipedia.org", "w3.org", "googleapis.com", "mozilla.org",
             "microsoft.com", "jquery.com", "custom-cursor.com"]
BOLD = '\033[1m'
RESETBOLD = '\033[0m'
#Exclude trusted extensions: "Chrome Media Router", "lastpass"
EXCLUDES = ["pkedcjkdefgpdelpbcmbmeomcjbeemfm", "hdokiejnpimakedhajhdlcegeplioahd",
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
        elif res.status_code == 404 and extension_id not in EXCLUDES:
            result[index] = {"folder": folder_name, "extension": extension_id, 'name': "UNKNOWN"}
        else:
            result[index] = {"folder": folder_name, "extension": extension_id, 'name': "ERROR"}
    except ConnectionError as err:
        print("There was a network connection error," \
             + "please verify https://chrome.google.com is reachable and try again")

    if len(sys.argv) > 1 and sys.argv[1] == 'checkExtensions':
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
                        domain_re = re.sub("\.$", "", _domain[0])
                        filtered_domains.append(domain_re + " -- " + file)
    result[index]['filtered_domains'] = filtered_domains



### MAIN ###
def main():
    '''
        Main Function
    '''
    json_data = ""

    url = "https://chrome.google.com/webstore/detail/"
    headers = {"accept-language": "en-US,en;q=0.9"}
    users = os.listdir("/Users")
    message = False

    for i in users:
        base_dirs = []
        if os.path.isfile("/Users/%s/Library/Application Support/Chromium/Local State" % (i)):
            base_dirs.append("/Users/%s/Library/Application Support/Chromium/" % (i))
        if os.path.isfile("/Users/%s/Library/Application Support/Google/Chrome/Local State" % (i)):
            base_dirs.append("/Users/%s/Library/Application Support/Google/Chrome/" % (i))
        if not base_dirs:
            continue
        #print(base_dirs)
        for base_dir in base_dirs:
            base_dir_split = base_dir.split("/")
            browser = base_dir_split[len(base_dir_split)-2]
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
                    if message == False:
                        print(BOLD + "Printing results WITHOUT URLs and IPs. Please add " \
                         + "\"checkExtensions\" argument in order to print it:\n " \
                          + "get_chrome_extensions.py checkExtensions\n"  + RESETBOLD)
                        message = True
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
                        print("\n\t" + BOLD + result[n]['folder'] + ":  " \
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
