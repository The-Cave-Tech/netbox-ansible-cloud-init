import argparse
import os

# Create the parser
parser = argparse.ArgumentParser(description='Process some files.')

# Add the arguments
parser.add_argument('--template', metavar='template', type=str, help='the path to the Jinja2 template')
parser.add_argument('--key', metavar='key', type=str, help='the path to the SSH public key')
parser.add_argument('--output', metavar='output', type=str, help='the path to the output file')

# Parse the arguments
args = parser.parse_args()

# Check if any of the required arguments are missing
if not all([args.template, args.key, args.output]):
    parser.print_help()
    exit()

# Read the SSH public key from the file
with open(args.key, 'r') as file:
    ssh_key = file.read().strip()

# Read the Jinja2 template from the file
with open(args.template, 'r') as file:
    template = file.read()

# Substitute the SSH key into the template
output = template.replace('{{ ssh_key }}', ssh_key)

# Write the output to the output file
with open(args.output, 'w') as file:
    file.write(output)
