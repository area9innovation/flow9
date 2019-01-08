<?php
	define('BASE_PATH', '../../../'); // flow root folder

	session_start();

	if (!isset($_SESSION['current_sequence'])) {
		$_SESSION['current_sequence'] = 0;
	}

	$dbg = isset($_GET['dbg']);

	if (isset($_GET['pushsnd'])) {
		$url = $_GET['pushsnd'];
		$_SESSION['current_sound'] = $url;
		$_SESSION['current_sequence'] += 1;

		//$path = BASE_PATH.$url;
		$path = $url;
		//echo "=" . $path . "=";
		$tmp_out_path = tempnam(sys_get_temp_dir(), "stream").".ts";

		if ($dbg) echo $tmp_out_path."\n";

		ob_start();
		passthru("ffmpeg -y -i \"".$path."\" -acodec libmp3lame -ab 16k ".$tmp_out_path." 2>&1");
		$duration = ob_get_contents();
		ob_end_clean();

		if ($dbg) echo $duration."\n";

		preg_match('/Duration: (.*?),/', $duration, $matches);
		$duration = $matches[1];
		list($hr,$m,$s) = explode(':', $duration);
		$duration_in_seconds = ( (int)$hr*3600 ) + ( (int)$m*60 ) + (int)$s;

		// save audio chunk in the current session
		$f = fopen($tmp_out_path, "rb");
		if ($f) {
			$contents = fread($f, filesize($tmp_out_path));
			fclose($f);
			$_SESSION['audiodata'] = $contents;

			if ($dbg) echo filesize($tmp_out_path)."\n";

			unlink($tmp_out_path);
		}

		header('Content-Type: text/plain'); 
		echo $duration_in_seconds;
	} else if (isset($_GET["audiodata"])) {
		//header('Content-Type: audio/mpeg');
		header('Content-Type: application/octet-stream'); 
		if (isset($_SESSION['audiodata'])) {
			echo $_SESSION['audiodata'];
		}
	} else {
		header('Content-type: application/vnd.apple.mpegurl');
		echo "#EXTM3U\n";
		echo "#EXT-X-VERSION:3\n";
		echo "#EXT-X-TARGETDURATION:1\n";
		echo "#EXT-X-MEDIA-SEQUENCE:".$_SESSION['current_sequence']."\n";
		echo "stream.php?audiodata\n";
	}
?>
