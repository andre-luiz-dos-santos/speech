$ = jQuery
recognition = null
listening = false
currentPage = 'main'
prettifyRules = null
emptyStringRe = /^\s*$/

# Controls the big button on the top left corner of the page.
# It's an incredibly ugly button, but it does its job.  :-)
changeStatus = (message, clickable = false) ->
	$('#start')
		.text(message)
		.prop('disabled', !clickable)
	return

# Capitalize the first letter of a sentence.
# Correct commonly misrecognized words.
prettifyText = (text) ->
	for rule in prettifyRules
		text = text.replace.apply(text, rule)
	return text

# Insert text into the main input text area.
# Add spaces around text when necessary.
addTranscription = do ->
	endWithSpace = new RegExp('(^|\n| )$')
	startWithSpace = new RegExp('^( |\n|$)')
	return (text) ->
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
	if loadData() is false then return
	if startRecognizer() is false then return
	new LanguagesSelectionPage()
	new PrettifyRulesPage()
	new SnippetsPage()
	attachEventHandlers()
	changeStatus("Start", true)
	$('#header .edit').fadeTo('slow', 0.5)
	return

switchToPage = (name) ->
	currentPage = name
	document.body.scrollTop = 0
	$('body > .page:visible').hide()
	$('#' + name + '-page').fadeIn()
	# return the page's <div>

attachEventHandlers = ->
	$('body').on 'keydown', (event) ->
		if currentPage is 'main'
			if event.which in [27] # Escape
				toggleListening()
			# Before copying (Control-C) or cutting (Control-X),
			# run 'prettify' if nothing is selected,
			# and then stop listening.
			if event.which in [67, 88] and event.ctrlKey is true
				elem = $('#text')[0]
				if elem.selectionStart is elem.selectionEnd
					$('#prettify').triggerHandler('click')
				if listening then toggleListening()
		return
	do (button = $("#start")) ->
		button.on 'click', (event) ->
			toggleListening()
			return
		return
	do (input = $('#text')) ->
		$('#prettify').on 'click', (event) ->
			input.val(prettifyText(input.val()))
			input[0].setSelectionRange(0, input.val().length)
			input.focus()
			return
		return
	do (select = $('#snippets')) ->
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
		$("#start").addClass('on')
		listening = true
		return

	recognition.onend = (event) ->
		changeStatus("Start", true)
		$("#start").removeClass('on')
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

loadData = ->
	unless 'localStorage' of window
		message = """
			Your browser does not support the Web Storage API.
			"""
		alert message
		$('body').empty().html(message.replace("\n", '<br>'))
		return false
	return true

class SingleTextboxPage
	constructor: ->
		@page = $('#' + @name + '-page')
		@textarea = $('textarea', @page)
		# Restore data
		@parse(@get())
		# Attach event handlers
		$('#menu-' + @name).on 'click', => @load() and @open()
		$('#save-' + @name).on 'click', => @save() and @close()
		$('#reset-' + @name).on 'click', => @reset() and @load()
	get: -> # Load data from localStorage
		localStorage[@name] ? @default
	set: (data) -> # Save data to localStorage (and to main page)
		if data is @default then return @reset()
		if @parse(data) is false then return false
		if @validate?() is false then return false
		localStorage[@name] = data
		return true
	open: -> # Show this page
		switchToPage(@name)
		@textarea.focus()
		return
	close: -> # Back to main page
		switchToPage('main')
		return
	load: -> # localStorage to DOM
		@textarea.val(@get())
		return true
	save: -> # DOM to localStorage
		@set(@textarea.val())
	reset: ->
		localStorage.removeItem(@name)
		@parse(@default)
		return true

class LanguagesSelectionPage extends SingleTextboxPage
	name: 'langs'
	constructor: ->
		@default = """
			# The first word is the language code, used by the speech recognition engine.
			# The rest of the line is just a label for the language selection box.
			pt-BR Portuguese
			en-US English

			# What language code should be used for Esperanto?
			eo Esperanto
			eo-EO Esperanto
			"""
		super
	validate: ->
		if @count() is 0
			alert("At least one language must be specified.")
			return false
		return true
	parse: (data) ->
		select = $('#language').empty()
		for line in data.split(/\r*\n+/)
			if /^\s*(#|$)/.test(line)
				# Comment or empty
			else if mo = line.match(/^\s*(\S+)\s+(\S.*)$/)
				$('<option>')
					.text(mo[2] + " (" + mo[1] + ")")
					.attr('value', mo[1])
					.appendTo(select)
			else
				alert("Invalid line:\n#{ line }")
				return false
		return true
	count: ->
		$('#language > option').length

class PrettifyRulesPage extends SingleTextboxPage
	name: 'rules'
	constructor: ->
		@default = """
			# Capitalize these words anywhere.
			[ /\\b(google|microsoft|portuguese|english|fastville|esperanto|português|inglês)\\b/g, capitalize ]
			[ /(free|open|net|dragon)bsd\\b/gi, function(_, b) { return capitalize(b) + 'BSD' } ]

			# Capitalize the first letter of each line.
			[ /^\\w/gm, capitalize ]

			# Capitalize the first letter after .?!
			[ /([.?!] )(\\w)/g, function(_, b, a) { return b + capitalize(a) } ]

			# Commonly misrecognized words.
			[ /\\big\\b/gi, 'e' ]
			[ /\\buol\\b/gi, 'ou' ]
			"""
		super
	parse: (data) ->
		prettifyRules = []
		capitalize = (w) ->
			w.substr(0,1).toUpperCase() + w.substr(1).toLowerCase()
		for line in data.split(/\r*\n+/)
			if /^\s*(#|$)/.test(line)
				# Comment or empty
			else if /^\s*\[.+\]\s*$/.test(line)
				try
					obj = eval(line)
				catch error
					alert("Invalid JavaScript: #{error}:\n#{line}")
					return false
				if not $.isArray(obj) or obj.length isnt 2
					alert("Not an array of length 2:\n#{line}")
					return false
				prettifyRules.push(obj)
			else
				alert("Invalid line:\n#{ line }")
				return false
		return true

class SnippetsPage extends SingleTextboxPage
	name: 'snippets'
	constructor: ->
		@default = """
			?
			!
			.
			,
			:-)
			:-(
			"""
		super
	parse: (data) ->
		select = $('#snippets').empty()
		$('<option>')
			.attr('value', "")
			.appendTo(select)
		for line in data.split(/\r*\n+/)
			if /^\s*(#|$)/.test(line)
				# Comment or empty
			else
				$('<option>')
					.text(line)
					.attr('value', line)
					.appendTo(select)
		return true
