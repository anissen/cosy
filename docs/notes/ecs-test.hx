typedef Pos = {
    var x: Float;
    var y: Float;
}
    
typedef Vel = {
    var x: Float;
    var y: Float;
}

class Test {
    static function main() {
        var entities   = [0, 1, 2];
        var positions  = [{x: 0, y: 0}, null, {x: 42, y: 66}];
        var velocities = [{x: 1, y: 1}, null, {x: 0, y: 0}];
        
        function print_positions() {
            for (e in entities) {
                var pos = positions[e];
                var vel = velocities[e];
                if (pos == null || vel == null) continue;
            	pos.x += vel.x;
            	pos.y += vel.y;
            	//trace(haxe.Json.stringify(positions[e]));
            }
        }
	    //print_positions();
    	function many() {
            for (i in 0...10000000) {
            	print_positions();    
            }
                return null;
        }
		trace(haxe.Timer.measure(many));
    
	    trace('---------');
    
	    main2();
    
    	trace('---------');
    
	    main3();
    }

	static function main2() {
        var entities   = [0, 1, 2];
        var positions  = [ 0 => {x: 0, y: 0}, 2 => {x: 42, y: 66} ];
		var velocities = [ 0 => {x: 1, y: 1}, 2 => {x: 0, y: 0} ];
        
        function print_positions() {
            for (e in entities) {
                var pos = positions[e];
                var vel = velocities[e];
                if (pos == null || vel == null) continue;
            	pos.x += vel.x;
            	pos.y += vel.y;
            	//trace(haxe.Json.stringify(positions[e]));
            }
        }
		function many() {
            for (i in 0...10000000) {
            	print_positions();    
            }
                return null;
        }
		trace(haxe.Timer.measure(many));
    }
        
    static function main3() {
        var entities   = [];
        var entity_id = 0;
        var positions  = [ 0 => {x: 0, y: 0}, 2 => {x: 42, y: 66} ];
		var velocities = [ 0 => {x: 1, y: 1}, 2 => {x: 0, y: 0} ];
        var components = new Map<Int, Map<String, Any>>();
        
        function create_entity() {
            var id = entity_id;
            entities.push(id);
            entity_id++;
            return id;
        }
        
        function add_component(entity, type, val) {
            var comps = components.get(entity);
            if (comps == null) {
                comps = new Map();
                components.set(entity, comps);
            }
            comps.set(type, val);
        }
        
        function add_position_component(entity, pos) {
            positions.set(entity, pos);
        }
        
        function add_velocity_component(entity, vel) {
            velocities.set(entity, vel);
        }
        
        var entity1 = create_entity();
        add_position_component(entity1, {x: 0, y: 0});
        add_component(entity1, 'pos', {x: 0, y: 0});
        add_velocity_component(entity1, {x: 1, y: 1});
        add_component(entity1, 'vel', {x: 1, y: 1});
        
        var entity2 = create_entity();
        
        var entity3 = create_entity();
        add_position_component(entity3, {x: 42, y: 66});
        add_velocity_component(entity3, {x: 0, y: 0});
        
        /*
		When adding/removing a component to/from an entity, match the entity against all systems.
        That is:
			for each system, s:
				for each component in the system, cs:
					check if the entity has all required components (cs)
					if it does, add the entity to the system
					otherwise, remove it from the system (if it is already in the system)
		Each system has a map of (entity, system components).
			The entity is used when removing the entity
			The system components are the data looped over
		See https://github.com/fponticelli/edge/blob/b56c002ea40d0e8dc228ae4a1740ca0ee5534eb1/demo/basic/bin/main.js#L155-L168
		*/
        
        function print_positions() {
            for (e in entities) {
                var pos = positions[e];
                var vel = velocities[e];
                if (pos == null || vel == null) continue;
            	pos.x += vel.x;
            	pos.y += vel.y;
            	trace(haxe.Json.stringify(positions[e]));
            }
        }
		print_positions();

		trace('comps:');

		function print_positions2() {
            for (e in entities) {
            	var comps = components[e];
             	if (comps == null) continue;
                var pos: Pos = comps['pos'];
                var vel: Vel = comps['vel'];
                if (pos == null || vel == null) continue;
            	pos.x += vel.x;
            	pos.y += vel.y;
            	trace(haxe.Json.stringify(positions[e]));
            }
        }
        print_positions2();
    }
}