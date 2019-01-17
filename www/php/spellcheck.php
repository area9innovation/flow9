<?php
// Parameters:
// action - required, type of requested action
if (!isset($_REQUEST['action'])) {
	echo "Error\nBad request format";
	return;
}

$action = $_REQUEST["action"];
switch($action) {
	case 'spellcheck':
		// Parameters:
		// words - required, array of items {"word" : "?", "lang" : "??"} in json format
		// dictionary - optional, path to personal dictionary file
		if (!isset($_REQUEST['words'])) {
			echo "Error\nBad request format";
			break;
		}
		$words_json = $_REQUEST["words"];
		$words_object = json_decode($words_json);

		$fnSpell = function($word_object) {
			// Example:
			// request:  [{"word":"Hello","lang":"en"},{"word":"are","lang":"en"},{"word":"haow","lang":"en"},{"word":"you","lang":"en"}]
			// response: [{"word":"Hello","lang":"en","correct":true},{"word":"are","lang":"en","correct":true},{"word":"haow","lang":"en","correct":false,"suggest":["ha ow","ha-ow","Haw","haw","how"]},{"word":"you","lang":"en","correct":true}]
			$word = $word_object->word;
			$lang = $word_object->lang;
			if (isset($_REQUEST['dictionary'])) {
				$dictionary = $_REQUEST["dictionary"];
				$pspell_link = pspell_new_personal($dictionary, $lang, "", "", "utf-8", PSPELL_FAST);
			} else {
				$pspell_link = pspell_new($lang, "", "", "utf-8", PSPELL_FAST);
			}
			if (!$pspell_link) return False;
			if (pspell_check($pspell_link, $word))
			{
				return ["word" => $word, "lang" => $lang, "correct" => True];
			} else {
				$suggest = pspell_suggest($pspell_link, $word);
				return ["word" => $word, "lang" => $lang, "correct" => False, "suggest" => array_slice($suggest, 0, 5)];
			}
		};

		$b = array_filter(array_map($fnSpell, $words_object));
		echo "OK\n".json_encode($b);
	break;
	case 'add2dictionary':
		// Parameters:
		// word - required, item {"word" : "?", "lang" : "??"} in json format
		// dictionary - required, path to personal dictionary file
		if (!isset($_REQUEST['word']) || !isset($_REQUEST['dictionary'])) {
			echo "Error\nBad request format";
			break;
		}
		$word_json = $_REQUEST["word"];
		$word_object = json_decode($word_json);
		$word = $word_object->word;
		$lang = $word_object->lang;
		$dictionary = $_REQUEST["dictionary"]."-".$lang;
		$pspell_link = pspell_new_personal($dictionary, $lang, "", "", "utf-8", PSPELL_FAST);
		if (!$pspell_link) {
			echo "Error\nCouldn't open dictionary '" . $dictionary . "'";
			break;
		}
		if (!pspell_add_to_personal($pspell_link, $word)) {
			echo "Error\nCouldn't add word '" . $word . "' to dictionary '" . $dictionary . "'";
			break;
		}
		if (!pspell_save_wordlist($pspell_link)) {
			echo "Error\nCouldn't save dictionary '" . $dictionary . "'";
			break;
		}
		echo "OK\nWord '" . $word . "' was saved to dictionary '" . $dictionary . "'";
	break;
	default:
		echo "Error\nUnknown operation: " . $action;
	break;
}
?>