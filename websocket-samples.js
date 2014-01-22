
var myApp = angular.module('myApp', []);

myApp.factory('CATSocketService', function ($rootScope) {
	var service = {};

	service.connect = function () {
		if (service.socket) return;
		service.socket = new WebSocket("ws://" + location.hostname + ":51234");

		service.socket.onopen = function () {
			console.log('onopen');
			if (service.onopen) service.onopen();
			$rootScope.$apply();
		};

		service.socket.onclose = function () {
			console.log('onclose');
			if (service.onclose) service.onclose();
			delete service.socket;
			setTimeout(function () {
				console.log('reconnecting');
				service.connect();
			}, 1000);
			$rootScope.$apply();
		};

		service.socket.onmessage = function (e) {
			var data = JSON.parse(e.data);
			console.log('ws.onmessage', data);
			if (service.onmessage) service.onmessage(data);
			$rootScope.$apply();
		};
	};

	service.send = function (data) {
		service.socket.send(JSON.stringify(data));
	};

	service.command = function (cmd, arg) {
		service.send({ command: cmd, value : arg });
	};

	return service;
});

myApp.controller('MyCtrl', function ($scope, $http, $timeout, CATSocketService) {
	CATSocketService.onopen = function () {
		$scope.connection = true;
	};

	CATSocketService.onclose = function () {
		$scope.connection = false;
	};

	CATSocketService.onmessage = function (data) {
		$scope.data            = JSON.stringify(data, null, 2);
		$scope.frequency       = data.frequency;
		$scope.mode            = data.mode;
		$scope.power           = data.power;
		$scope.vfo             = data.vfo;
		$scope.width           = data.width;
		$scope.noise_reduction = data.noise_reduction;
	};

	$scope.setPower = function () {
		CATSocketService.command('power', +$scope.power);
	};

	$scope.setWidth = function () {
		CATSocketService.command('width', +$scope.width);
	};

	$scope.setMode = function () {
		CATSocketService.command('mode', $scope.mode);
	};

	$scope.setFrequency = function (frequency) {
		CATSocketService.command('frequency', $scope.frequency);
	};

	$scope.setNoiseReduction = function () {
		CATSocketService.command('noise_reduction', +$scope.noise_reduction);
	};

	var timer, willChange;
	$scope.handleKey = function (e) {
		if (!willChange) willChange = $scope.frequency;
		if (e.keyCode === 38) { // UP
			willChange += 10;
		} else
		if (e.keyCode === 40) { // DOWN
			willChange -= 10;
		}
		$scope.frequency = willChange;

		$timeout.cancel(timer);
		timer = $timeout(function () {
			$scope.frequency = willChange;
			$scope.setFrequency();
			willChange = null;
		}, 1000);
	};

	CATSocketService.connect();
});
