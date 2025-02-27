<?php

/*
parameters:
json=true shows all possible values
json=simple skips md5 and size
h=something shows timestamp in human-readable format
*/

date_default_timezone_set('UTC');
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");

// don't want to include anything, so copied from util.php
function getParameter($f) {
  if (isset($_POST[$f])) {
	return $_POST[$f];
  }
  if (isset($_GET[$f])) {
	return $_GET[$f];
  }
  return null;
}

$allowedParameters = ['file', 'json', 'h', 'db', 't'];
$parameters = array_merge($_POST, $_GET);
if (!empty($parameters)) {
	foreach ($parameters as $key => $value) {
		if (!in_array($key, $allowedParameters)) {
			http_response_code(400);
		}
	}
}

// $root = '/var/www/html/flow';
$root = str_replace("/php/stamp.php", "", __FILE__); // on the server, contents of flow/www are copied to .../flow. Differs from repository path
if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
	// we expect this script to be in a folder inside flow, so flow is one level up
	$pi = pathinfo(__FILE__);
	$root = dirname($pi['dirname']);
}

$file = getParameter('file') ?? '';
$absoluteFile = $root . '/' . trim($file, '/');

$timestamp = 0;

// supress warnings in file_exists because we may be probed with bogus paths
// and php complains in that case
if (strpos($file, '..') === false && @file_exists($absoluteFile)) {
	// just to be safe let's ignore paths with returns
	$timestamp = filemtime($absoluteFile);
}

$hrts = date('Y-m-d G:i', $timestamp);
$isJson = getParameter('json') != '';
if ($isJson) {
	header('Content-type: application/json');
	$data = array();
	$data['timestamp'] = $timestamp;
	$data['date'] = $hrts;
	if (is_file($absoluteFile)) {
		$data['file'] = true;
		if (getParameter('json') == 'true') {
			$data['md5'] = md5_file($absoluteFile);
			$data['size'] = filesize($absoluteFile);
		}
	} else {
		$data['file'] = false;
	}
	echo json_encode($data);
} else {
	header('Content-type: text/plain');
	$humanFormat = getParameter('h') != '';
	$dbFormat = getParameter('db') != '';
	if ($humanFormat) {
		echo $hrts;
	} elseif ($dbFormat) {
		echo date('Y-m-d H:i:s', $timestamp);
	} else {
		echo $timestamp;
	}
}

