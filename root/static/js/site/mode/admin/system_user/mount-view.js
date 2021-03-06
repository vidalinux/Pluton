site.mode.admin.system_user.methods['mount-view'] = Meta( site.obj.method ).extend({
    mount: null,
    preDrawUI: function() {
        var queue = Meta.queue.$(function() {
            cb(site.data);
        });

        var mounts = site.data.system_users.mounts,
            mount,
            params = site.data.params;

        for (var i = 0; i < mounts.length; i++) {
            if (mounts[i].id == params.mid) {
                mount = mounts[i];
                break;
            }
        }

        var type = site.mode.admin.system_user.calculateMountType( mount.storage_url );
        mount.type = {};
        mount.type[type] = 1;

        mount.params = params;

        site.mounts[type].paramsToDom( mount );
        this.mount = mount;
    },
    drawUI: function() {
        site.mode.admin.system_user.methods.main.drawUI();
        var $container = this.$container = Meta.dom.$().select('#system_user-container');
        $container.inner(site.mustache.render('system_user-mount-view', this.mount));
    },
    postDrawUI: function() {
        var mount = this.mount;
        var params = site.data.params;

        var $container = this.$container;

        $container.select('#system_user-mount-generate_authinfo2').on('click', function() {
            site.mode.admin.system_user.mountAuthinfo2( params );
            Meta.jsonrpc.execute();
            return false;
        });

        $container.select('#system_user-mount-generate_mkfs').on('click', function() {
            site.mode.admin.system_user.mountMkfs( params );
            site.mode.admin.system_user.getMountStatus( params.user, params.mid, function(result){
                $container.select('#system_user-mount-status').text( result );
            });
            Meta.jsonrpc.execute();
            return false;
        });

        $container.select('#system_user-mount-generate_remount').on('click', function() {
            site.mode.admin.system_user.mountRemount( params );
            site.mode.admin.system_user.getMountStatus( params.user, params.mid, function(result){
                $container.select('#system_user-mount-status').text( result );
            });
            Meta.jsonrpc.execute();
            return false;
        });

        $container.select('#system_user-mount-generate_umount').on('click', function() {
            site.mode.admin.system_user.mountUmount( params );
            site.mode.admin.system_user.getMountStatus( params.user, params.mid, function(result){
                $container.select('#system_user-mount-status').text( result );
            });
            Meta.jsonrpc.execute();
            return false;
        });

        $container.select('#system_user-mount-generate_rmmount').on('click', function() {
            site.mode.admin.system_user.rmMount( params );
            Meta.jsonrpc.execute();
            return false;
        });

        site.mode.admin.system_user.getMountStatus( params.user, params.mid, function(result){
            $container.select('#system_user-mount-status').text( result );
        });
        Meta.jsonrpc.execute();
    }
});
