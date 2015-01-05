'use strict';

// Declare app level module which depends on views, and components
var app = angular.module('shuppin', [
  'ngRoute',
  'itemsTable',
  'myApp.version',
  'toggle-switch',
]);

app.config(['$routeProvider', function($routeProvider) {
  //$routeProvider.otherwise({redirectTo: '/view2'});
}]);


app.controller('MainController', function($scope) {

        this.switchStatus = {};

        this.items = [
            {
                "name"      : "tomatoes",
                "status"    :   true,
            },
            {
                "name"      : "cucumbers",
                "status"    :   false,
            },
        ];

        this.addItem = function(item) {
            this.items[item] = false;
        }

        this.removeItem = function(item) {
            delete this.items[item];
        }

        this.changeSwitch = function() {
            alert("amir");
        }

});

