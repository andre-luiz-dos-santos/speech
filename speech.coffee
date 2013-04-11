$ = jQuery
recognition = null
listening = false

# Controls the big button on the top left corner of the page.
# It's an incredibly ugly button, but it does its job.  :-)
changeStatus = (message, clickable = false) ->
	$('#start')
		.text(message)
		.prop('disabled', !clickable)
	return

# Capitalize the first letter of a sentence.
# Correct commonly misrecognized words.
prettifyText = do ->
	lineStart = /(^|[.!?)]\s+)(\w)/g
	alwaysCapitalize = /\b(google|microsoft|portuguese|english|fastville|esperanto|português|inglês)\b/g
	return (text) -> text
		.replace(lineStart, (_,l,u) -> l + u.toUpperCase())
		.replace(alwaysCapitalize, (w) -> w.substr(0,1).toUpperCase() + w.substr(1).toLowerCase())
		.replace(/\big\b/g, 'e')
		.replace(/\buol\b/g, 'ou')

# Insert text into the main input text area.
# Add spaces around text when necessary.
addTranscription = do ->
	endWithSpace = new RegExp('(^|\n| )$')
	startWithSpace = new RegExp('^( |\n|$)')
	return (text) ->
		console.log text
		input = $('#text')
		elem = input[0]
		startPosition = elem.selectionStart
		endPosition = elem.selectionEnd
		oldText = input.val()
		beforeText = oldText.substr(0, startPosition)
		afterText = oldText.substr(endPosition)
		text = text.replace(/^ +| +$/, '')
		text = " " + text unless endWithSpace.test(beforeText)
		text = text + " " unless startWithSpace.test(afterText)
		newText = beforeText + text + afterText
		input.val(newText)
		newPosition = startPosition + text.length
		elem.setSelectionRange(newPosition, newPosition)
		return

$ ->
	if startRecognizer() is false
		return
	attachEventHandlers()
	changeStatus("Start", true)
	return

attachEventHandlers = ->
	do (button = $("#start")) ->
		button.on 'click', (event) ->
			toggleListening()
			return
		$('body').on 'keydown', (event) ->
			if event.which in [27, 45] # Insert, Escape
				toggleListening()
			if event.which in [67, 88] and event.ctrlKey is true # Control-C -X
				$('#prettify').triggerHandler('click')
				if listening then toggleListening()
			return
		return
	do (input = $('#text')) ->
		$('#prettify').on 'click', (event) ->
			input.val(prettifyText(input.val()))
			input[0].setSelectionRange(0, input.val().length)
			input.focus()
			return
		return
	do (select = $('#templates')) ->
		select.on 'change', (event) ->
			addTranscription(select.val())
			select.val('')
			return
		return
	return

toggleListening = ->
	if $("#start").prop('disabled') is true
		return # already starting or stopping
	if listening
		changeStatus("Stopping")
		recognition.stop()
	else
		changeStatus("Starting")
		recognition.lang = $('#language').val()
		recognition.start()
	return

startRecognizer = ->
	unless 'webkitSpeechRecognition' of window
		message = """
			Your browser does not support the Web Speech API.
			Try again using Google Chrome.
			"""
		alert message
		$('body').empty().html(message.replace("\n", '<br>'))
		return false

	recognition = new webkitSpeechRecognition()
	recognition.continuous = true
	recognition.interimResults = true

	recognition.onstart = (event) ->
		$('#error').hide()
		changeStatus("Stop", true)
		listening = true
		return

	recognition.onend = (event) ->
		changeStatus("Start", true)
		listening = false
		$('#interim').text("...")
		return

	recognition.onerror = (event) ->
		console.log event
		$('#error').text(event.error).show()
		return

	recognition.onresult = (event) ->
		interim = ""
		i = event.resultIndex
		while i < event.results.length
			result = event.results[i]; i += 1
			if result.isFinal then addTranscription(result[0].transcript)
			else interim += result[0].transcript
		$('#interim').text(interim || "...")
		return

	return true
