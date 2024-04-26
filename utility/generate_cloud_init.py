import argparse
from jinja2 import Environment, FileSystemLoader

# Create the parser
parser = argparse.ArgumentParser(description='Substitute variables in a Jinja2 template.')

# Add the arguments
parser.add_argument('--template', metavar='template', type=str, required=True, help='the path to the Jinja2 template')
parser.add_argument('--output', metavar='output', type=str, required=True, help='the path to the output file')
parser.add_argument('--ssh_key', metavar='ssh_key', type=str, required=True, help='the value for the ssh_key variable')
parser.add_argument('--vmname', metavar='vmname', type=str, required=True, help='the value for the vmname variable')

# Parse the arguments
args = parser.parse_args()

# Load the template
env = Environment(loader=FileSystemLoader('/'))
template = env.get_template(args.template)

# Substitute the variables
output = template.render(ssh_key=args.ssh_key, vmname=args.vmname)

# Write the output to the output file
with open(args.output, 'w') as file:
    file.write(output)
