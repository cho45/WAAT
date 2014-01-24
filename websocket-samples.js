
var myApp = angular.module('myApp', []);

myApp.factory('CATSocketService', function ($rootScope, $q) {
	var service = {};
	var deferred = {};
	var id = 1;

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
			if (deferred[data.id]) {
				if (data.error) {
					deferred[data.id].reject(data.error);
				} else {
					deferred[data.id].resolve(data.result);
				}
				delete deferred[data.id];
			}
			$rootScope.$apply();
		};
	};

	service.send = function (data) {
		service.socket.send(JSON.stringify(data));
	};

	service.command = function (cmd, arg) {
		var call = { id: id++, method: cmd, params : [ arg ] };
		service.send(call);
		deferred[call.id] = $q.defer();
		return deferred[call.id].promise;
	};

	return service;
});

myApp.controller('MyCtrl', function ($scope, $http, $timeout, $window, CATSocketService) {
	$window.CATSocketService = CATSocketService;

	CATSocketService.onopen = function () {
		$scope.connection = true;
	};

	CATSocketService.onclose = function () {
		$scope.connection = false;
	};

	CATSocketService.onmessage = function (data) {
		if (!data.id) {
			var result = data.result;
			$scope.data            = JSON.stringify(result, null, 2);
			$scope.frequency       = result.frequency;
			$scope.mode            = result.mode;
			$scope.power           = result.power;
			$scope.vfo             = result.vfo;
			$scope.width           = result.width;
			$scope.noise_reduction = result.noise_reduction;
		}
	};

	$scope.setPower = function () {
		CATSocketService.command('power', +$scope.power);
	};

	$scope.setWidth = function () {
		CATSocketService.command('width', +$scope.width).then(function (r) {
			console.log(['callback', r]);
		});
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
			willChange += 100;
		} else
		if (e.keyCode === 40) { // DOWN
			willChange -= 100;
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
