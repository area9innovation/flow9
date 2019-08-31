<?php
    $server_key = "";
    $doSubscribe = $_POST["doSubscribe"];
    $topic = $_POST["topic"];
    $iid_token = $_POST["token"];

    $curlUrl = "https://iid.googleapis.com/iid/v1:batch" . ($doSubscribe ? "Add" : "Remove");

    $ch = curl_init($curlUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        "Authorization:key=".$server_key,
        "Content-Type:apllication/json"
    ));
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode(array(
        "to" => $topic,
        "registration_tokens" => [$iid_token]
    )));
    
    curl_exec($ch);
    curl_close($ch);
?>
