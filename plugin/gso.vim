python3 << EOF

import sys
import vim

sys.path.insert(0, vim.eval("expand('<sfile>:p:h')"))

if "gso" in sys.modules:
    from importlib import reload
    gso = reload(gso)
else:
    import gso
EOF

function! GSO(...)

let all_args=a:000

python3 << EOF

import vim
import os
import argparse
from io import BytesIO
from lxml import etree
from gso import load_up_answers, load_up_questions

# ["___", "____"] - interpreted as block comment
# "___" - interpreted as single-line comment
comments = {
    'python': ["\"\"\"", "\"\"\""],
    'haskell': ["{-", "-}"],
    'cpp': ["/*", "*/"],
    'c++': ["/*", "*/"],
    'c': ["/*", "*/"],
    'cuda': ["/*", "*/"],
    'java': ["/*", "*/"],
    'rust': ["/*", "*/"],
    'php': ["/*", "*/"],
    'javascript': ["/*", "*/"],
    'ruby': ["=begin ", "=end "],
    'perl': ["=begin ", "=cut "],
    'tex': "%",
    'plaintex': "%",
    'latex': "%",
    'html': ["<!--", "-->"],
    'sh': "#",
    'bash': "#",
    'zsh': "#",
    'shell': "#",
    'make': "#",
    'vim': "\" "
}

# Some filetypes from vim 
# should be searched with a different
# name.
search_mapping = {
    'cpp': 'C++',
    'sh': 'shell script',
    'make': 'makefile'
}


"""Load up options"""

all_args = vim.eval("all_args")

"""Get default language"""
curr_lang = ""
try:
    curr_lang = vim.current.buffer.vars['current_syntax']
except:
    pass

"""Text turned on?"""
no_text = False

"""Create parser for args"""
parser = argparse.ArgumentParser(description="Process a search query")

parser.add_argument(
    '-l', '--language', default=curr_lang, help="Set the language explicitly")
parser.add_argument(
    '-n', '--no-text', action='store_true', default=False,
    help="Don't print the answer text")
parser.add_argument('search', nargs='+', help="The search keywords")

"""Parse!"""
gso_command = vars(parser.parse_args(all_args))

curr_lang = gso_command['language'].lower()
no_text = gso_command['no_text']
question = gso_command['search']

"""Now all the options are loaded"""

starting_line = vim.current.window.cursor[0]
current_line = starting_line

results = []
i = 0

no_language_setting = ['none', 'nothing', 'no']
# Should we search it with a different name?
search_lang = curr_lang
if curr_lang in search_mapping:
    search_lang = search_mapping[curr_lang]
elif curr_lang in no_language_setting:
    search_lang = ""

for result in load_up_questions(str(question), search_lang):
    results.append(result)
    i += 1
    if i > 0:
        break

question_url = results[0][0]
answers = load_up_answers(question_url)

def wrap_with_root_tag(xml_string):
    xml_string = u"<root>"+xml_string+u"</root>"
    return xml_string

parser = etree.XMLParser(recover=True)
root = etree.parse(
    BytesIO(wrap_with_root_tag(answers[0][1]).encode('utf-8')),
    parser=parser)


# Inside a code block
inside_pre_tag = False
# Inside a comment block
inside_comment = False

block_comments_enabled = False
if curr_lang in comments and not isinstance(comments[curr_lang], str):
    block_comments_enabled = True

#Mark the start of input
if block_comments_enabled:
    vim.current.buffer.append(
        comments[curr_lang][0]+"GSO>>>"+comments[curr_lang][1],
        current_line)
elif curr_lang in comments:
    vim.current.buffer.append(
        comments[curr_lang]+"GSO>>>",
        current_line)
else:
    vim.current.buffer.append(
        "GSO>>>", current_line)

for elem in root.iter():
    known_tags = [
        'pre', 'code', 'p', 'kbd',
        'a', 'li', 'em', 'ol', 'strong'
    ]
    if elem.tag not in known_tags:
        continue
    inline_tags = [
        'code', 'kbd', 'a', 'em', 'strong'
    ]

    if elem.tag == 'pre':
        inside_pre_tag = True
    elif not inside_pre_tag and no_text:
        """No printing out text of answer"""
        continue

    if inside_comment == False and inside_pre_tag == False:
        """Start a block comment"""
        if block_comments_enabled:
            vim.current.buffer[current_line] += comments[curr_lang][0]
            inside_comment = True
    if inside_comment == True and inside_pre_tag == True:
        """End a block comment"""
        if block_comments_enabled:
            vim.current.buffer.append(
                comments[curr_lang][1], current_line+1)
            current_line += 1
            inside_comment = False

    if elem.tag not in inline_tags:
        if curr_lang in comments and not block_comments_enabled and not inside_pre_tag:
            """Do a single line comment"""
            vim.current.buffer.append('', current_line+1)
            vim.current.buffer[current_line+1] += comments[curr_lang]
        else:
            vim.current.buffer.append('', current_line+1)
        current_line += 1

    text = ""
    tail = ""
    try:
        text = str(elem.text)
    except AttributeError:
        text = ""
        pass
    try:
        tail = str(elem.tail)
    except AttributeError:
        tail = ""
        pass

    for line in text.split('\n'):
        if line != "None":
            vim.current.buffer[current_line] += line
        if elem.tag == 'code' and inside_pre_tag == True:
                vim.current.buffer.append('', current_line+1)
                current_line += 1


    for line in str(tail).split('\n'): #213 = 186
        if line != "None":
            vim.current.buffer[current_line] += line
    if elem.tag == 'code' and inside_pre_tag == True:
        inside_pre_tag = False



if inside_comment == True:
    if block_comments_enabled:
        vim.current.buffer.append(
            comments[curr_lang][1], current_line+1)
        current_line += 1
        inside_comment = False

#Mark the end of input
if block_comments_enabled:
    vim.current.buffer.append(
        comments[curr_lang][0]+"<<<GSO"+comments[curr_lang][1],
        current_line+1)
    vim.current.buffer.append(
        comments[curr_lang][0]+question_url+comments[curr_lang][1],
        current_line+1)
elif curr_lang in comments:
    vim.current.buffer.append(
        comments[curr_lang]+"<<<GSO",
        current_line+1)
    vim.current.buffer.append(
        comments[curr_lang]+question_url,
        current_line+1)
else:
    vim.current.buffer.append(
        "<<<GSO", current_line+1)
    vim.current.buffer.append(
        question_url, current_line+1)

EOF

endfunction

command! -nargs=* GSO call GSO(<f-args>)
