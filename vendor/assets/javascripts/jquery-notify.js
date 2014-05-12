/**
 * Notification JS
 * Creates Notifications
 * @author Andrew Dodson
 */

(function($){

	// Relative Directory
	var dir = (function(){
					var script = document.getElementsByTagName("script");
					script = script[script.length-1];
					return ( script.src || script.getAttribute("src",4) ).replace(/[^\/]+$/, '');
				})();

	// default icon
	var star = dir + "star.ico";

	// Unique reference of the items in the 
	var guid = [];


	$.extend({
		// Check for browser support
		notifyCheck : function(){
			// Check whether the current desktop supports notifications and if they are authorised, 
			// 0 (yes they are supported and permission is granted), 
			// 1 (yes they are supported, permission has not been granted), 
			// -1 (Notifications are not supported)
			
			// IE9
			if(("external" in window) && ("msIsSiteMode" in window.external)){
				return window.external.msIsSiteMode() ? 0 : 1;
			}
			else if("webkitNotifications" in window){
				return window.webkitNotifications.checkPermission() === 0 ? 0 : 1;
			}
			else if("Notification" in window) {
				return (Notification.permission === 'granted') ? 0 : 1;
			}
			else {
				return -1;
			}
		},

		// Request browser adoption
		notifyRequest : function(cb){
			// Setup
			// triggers the authentication to create a notification
			cb = cb || function(){};
	
			// IE9
			if(("external" in window) && ("msIsSiteMode" in window.external)){
				if( !window.external.msIsSiteMode() ){
					window.external.msAddSiteMode();
	 				return true;
				}
				else {
					cb();
					return false;
				}
			}
			// If Chrome and not already enabled
			else if("webkitNotifications" in window && window.webkitNotifications.checkPermission() !== 0 ){
				return window.webkitNotifications.requestPermission(cb);
			}
			else if("Notification" in window) {
				Notification.requestPermission(cb);
			}
			else {
				cb();
				return null;
			}
		},

		// Notify
		notify : function(icon, title, description, callback){
	
			// Create a notification
			createNotification( icon || star, title, description);
		}
	});

	function createNotification(icon, title, description, ttl){
		// Create a notification
		// @icon string
		// @title string
		// @description string
		// @ttl string
		
		// 
		// Create Desktop Notifications
		// 
		if(("external" in window) && ("msIsSiteMode" in window.external)){
			if(window.external.msIsSiteMode()){
				window.external.msSiteModeActivate();
				
				if(icon){
					window.external.msSiteModeSetIconOverlay(icon, title);
				}

				return true;
			}
			return false;
		}
		else if("webkitNotifications" in window){
			if(window.webkitNotifications.checkPermission() === 0){
				n = window.webkitNotifications.createNotification(icon, title, description )
				n.show();
				n.onclick = function(){
					// redirect the user back to the page
					window.focus();
					setTimeout( function(){ n.cancel(); }, 1000);
				};
				if(ttl>0){
					setTimeout( function(){ n.cancel(); }, ttl);
				}
				return n;
			}
			return false;
		}
		else if( "mozNotification" in window.navigator ){
			var m = window.navigator.mozNotification.createNotification( title, description, icon );
			m.show();
			return true;
		}
		else if("Notification" in window) {
			n = new Notification(title, {
				'icon': icon,
				'body': description
			});
			n.onclick = function(){
				// redirect the user back to the page
				window.focus();
				setTimeout( function(){ n.close(); }, 1000);
			};
			if(ttl > 0){
				setTimeout( function(){ n.close(); }, ttl);
			}
		}
		else {
			return null;
		}
	};
	
})(jQuery);