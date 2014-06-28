//Attach click event handlers to buttons
//Upon click, the content of <div id=game_area> in game.erb will be replaced

//Attach a click event handler to the player hit button
$(document).ready( function() {
	$(document).on('click','#hit_form input', function (){
		$.ajax({
			type: 'POST',
			url: '/game/player/hit'
		}).done(function(msg){
		$('#game_area').replaceWith(msg);
	});
	return false;

	});
});

//Attach a click event handler to the player stay button
$(document).ready( function() {
	$(document).on('click','#stay_form input', function (){
		$.ajax({
			type: 'POST',
			url: '/game/player/stay'
		}).done(function(msg){
		$('#game_area').replaceWith(msg);
	});
	return false;

	});
});

//Attach a click event handler to the dealer hit button
$(document).ready( function() {
	$(document).on('click','#dealer_hit_form input', function (){
		$.ajax({
			type: 'POST',
			url: '/game/dealer/hit'
		}).done(function(msg){
		$('#game_area').replaceWith(msg);
	});
	return false;

	});
});
