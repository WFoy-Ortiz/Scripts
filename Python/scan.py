import os
import time
import subprocess
import sys

def show_help():
    help_message = """
    Usage: sudo python3 scan.py [options]

    Options:
      --help        Show this help message and exit

    Description:
      This script facilitates running nmap scans with various options provided by the user.
      
      Steps:
      1. Ensure you run the script with sudo.
      2. The script will prompt you for the following:
         - Output file name for the scan results (used with the -oN flag).
         - Whether you want to scan a single IP or a list of IPs.
         - If scanning a list of IPs, provide the path to the list file (used with the -iL flag).
         - Optionally, append the output to a previous scan file by providing the path to that file.
      3. If scanning a list of IPs, the script will execute scans on each IP with a 2-minute delay between each scan.

    Example Usage:
      sudo python3 scan.py
    """
    print(help_message)

def check_sudo():
    # Check if the script is running with elevated privileges
    if os.geteuid() != 0:
        print("This script must be run with sudo. Please rerun with 'sudo python3 scan.py'.")
        sys.exit(1)

def run_command():
    # Get the output file name
    output_file = input("Enter the file name for the output (-oN): ")

    # Ask for the IP address or list of IPs
    scan_list = input("Do you want to scan a list of IPs? (yes/no): ").strip().lower()
    if scan_list == 'yes':
        ip_list_path = input("Enter the path to the IP list file (-iL): ")
        scan_mode = '-iL ' + ip_list_path
    else:
        ip_address = input("Enter the IP address to scan: ")
        scan_mode = ip_address

    # Ask if the user wants to append to a previous file
    append_output = input("Do you want to append the output to a previous scan file? (yes/no): ").strip().lower()
    if append_output == 'yes':
        previous_file_path = input("Enter the path to the previous scan file: ")
        append_mode = '--append-output ' + previous_file_path
    else:
        append_mode = ''

    # Base command
    command = f"nmap -Pn -n -sC -sV -p 0-1024,1433,1812,2077,2078,2222,3306,3389,8000,8080,8443 -oN {output_file} -vvv --open {scan_mode} {append_mode}"

    # If scanning a list, handle the delay between each scan
    if scan_list == 'yes':
        with open(ip_list_path, 'r') as file:
            ips = file.readlines()

        for ip in ips:
            ip = ip.strip()
            if ip:
                single_command = f"nmap -Pn -n -sC -sV -p 0-1024,1433,1812,2077,2078,2222,3306,3389,8000,8080,8443 -oN {output_file} -vvv --open {ip} {append_mode}"
                print(f"Running command: {single_command}")
                subprocess.run(single_command, shell=True)
                time.sleep(120)  # Delay for 2 minutes
    else:
        # Run the command
        print(f"Running command: {command}")
        subprocess.run(command, shell=True)

if __name__ == "__main__":
    # Check for help argument or no arguments
    if len(sys.argv) == 1 or '--help' in sys.argv:
        show_help()
        sys.exit(0)
    
    check_sudo()
    run_command()
