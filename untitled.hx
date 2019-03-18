			if (typeof localStream !== 'undefined') {
				try {
					var pc = new RTCPeerConnection(pcConfig);
					pc.clientId = clientId;
					pc.onicecandidate = handleIceCandidate;
					pc.onaddstream = handleRemoteStreamAdded;
					pc.onremovestream = handleRemoteStreamRemoved;

					peerConnections[clientId].addStream(localStream);
					peerConnections[clientId] = pc;
				} catch (e) {
					console.log('Failed to create PeerConnection, exception: ' + e.message);
					alert('Cannot create RTCPeerConnection object.');
					return;
				}
		}