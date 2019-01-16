#!/usr/bin/python

# This script starts the flowc server, and provides
# a port tunneling for this server, which rejects
# requests while server is busy (i.e. do not queue
# requests). 
#
# Two parameters optional may be passed:
# - the first: the port, which is visible to a client. 
#   Default value: 10001
# - the second: the port, which is used by a proxied server.
#   Default value: 10002.
# If these ports coincide, they are made different.

import socket
import sys
import os
import thread
import time
import subprocess

def main(input_port, server_port):
	compiler_args = ['flowc1', 'server-mode=1', 'server-port=' + str(server_port)]
	proc = subprocess.Popen(compiler_args)
	thread.start_new_thread(server, (input_port, server_port))
	proc.communicate()

def server(input_port, server_port):
	try:
		dock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		dock_socket.bind(('', input_port))
		dock_socket.listen(5)
		while True:
			client_socket = dock_socket.accept()[0]
			server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
			server_socket.connect(('localhost', server_port))
			thread.start_new_thread(forward_request, (client_socket, server_socket))
			thread.start_new_thread(forward_response, (server_socket, client_socket))
	finally:
		thread.start_new_thread(server, ports)

request_sent = False

def forward_request(source, destination):
	global request_sent
	if request_sent:
		print('Request ignored, because server is busy.')
		source.sendall('HTTP/1.1 503 Server is busy.\r\n\r\n')
	else:
		request_sent = True
		string = ' '
		while string:
			string = source.recv(1024)
			if string:
				destination.sendall(string)
			else:
				source.shutdown(socket.SHUT_RD)
				destination.shutdown(socket.SHUT_WR)

def forward_response(source, destination):
	global request_sent
	string = ' '
	while string:
		string = source.recv(1024)
		if string:
			destination.sendall(string)
		else:
			request_sent = False
			destination.shutdown(socket.SHUT_WR)

if __name__ == '__main__':
	input_port = 10001
	if len(sys.argv) > 1:
		input_port = int(sys.argv[1])
	server_port = 10002
	if len(sys.argv) > 2:
		server_port = int(sys.argv[2])
	if server_port == input_port:
		server_port += 1
	main(input_port, server_port)
