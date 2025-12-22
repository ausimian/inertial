#include <assert.h>
#include <errno.h>
#include <stddef.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/kern_event.h>
#include <netinet/in_var.h>
#include <netinet6/in6_var.h>
#include <erl_nif.h>
#include <erl_driver.h>

static ERL_NIF_TERM s_ok;
static ERL_NIF_TERM s_error;
static ERL_NIF_TERM s_failed;
static ERL_NIF_TERM s_nil;
static ERL_NIF_TERM s_vendor;
static ERL_NIF_TERM s_class;
static ERL_NIF_TERM s_subclass;
static ERL_NIF_TERM s_type;
static ERL_NIF_TERM s_link_up;
static ERL_NIF_TERM s_link_down;
static ERL_NIF_TERM s_new_addr;
static ERL_NIF_TERM s_del_addr;
static ERL_NIF_TERM s_ifname;
static ERL_NIF_TERM s_addr;
static ERL_NIF_TERM s_unhandled_event;

static ERL_NIF_TERM make_error(ErlNifEnv *env, int err)
{
    return enif_make_tuple2(env, s_error, enif_make_atom(env, erl_errno_id(err)));
}

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info)
{
    (void)priv_data;
    (void)load_info;
    s_ok = enif_make_atom(env, "ok");
    s_error = enif_make_atom(env, "error");
    s_failed = enif_make_atom(env, "failed");
    s_nil = enif_make_atom(env, "nil");
    s_vendor = enif_make_atom(env, "vendor");
    s_class = enif_make_atom(env, "class");
    s_subclass = enif_make_atom(env, "subclass");
    s_type = enif_make_atom(env, "type");
    s_link_up = enif_make_atom(env, "link_up");
    s_link_down = enif_make_atom(env, "link_down");
    s_new_addr = enif_make_atom(env, "new_addr");
    s_del_addr = enif_make_atom(env, "del_addr");
    s_ifname = enif_make_atom(env, "ifname");
    s_addr = enif_make_atom(env, "addr");
    s_unhandled_event = enif_make_atom(env, "unhandled_event");
    return 0;
}

static ERL_NIF_TERM set_event_filter(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    if( argc != 2 || !enif_get_int( env, argv[0], &fd ) || !enif_is_map( env, argv[1] ) )
    {
        return enif_make_badarg( env );
    }
    
    struct kev_request filter = { 0 };
    struct kern_event_msg;

    ERL_NIF_TERM key, val;
    ErlNifMapIterator iter;
    enif_map_iterator_create( env, argv[ 1 ], &iter, ERL_NIF_MAP_ITERATOR_FIRST );
    while( enif_map_iterator_get_pair( env, &iter, &key, &val ) )
    {
        int ival;
        if( enif_get_int( env, val, &ival ) && ival >= 0 )
        {
            if( enif_compare( key, s_vendor ) == 0 )
            {
                filter.vendor_code = (uint32_t) ival;
            }
            else if( enif_compare( key, s_class ) == 0 )
            {
                filter.kev_class = (uint32_t) ival;
            }
            else if( enif_compare( key, s_subclass ) == 0 )
            {
                filter.kev_subclass = (uint32_t) ival;
            }
        }
        enif_map_iterator_next( env, &iter );
    }
    enif_map_iterator_destroy( env, &iter );
    
    struct kev_request req = { 0 };

    if( ioctl( fd, SIOCSKEVFILT, &req ) )
    {
        return make_error( env, errno );
    }

    return s_ok;
}

static ERL_NIF_TERM parse_dl_event(ErlNifEnv *env, const struct kern_event_msg *msg, ERL_NIF_TERM *events)
{
    (void)events;
    const struct net_event_data *data = (void*)&msg->event_data[0];

    switch( msg->event_code )
    {
        case KEV_DL_LINK_ON:
        case KEV_DL_LINK_OFF:
        {
            char tmp[IFNAMSIZ] = { 0 };
            int len = snprintf(tmp, sizeof(tmp), "%s%u", data->if_name, data->if_unit);
            if( len >= 0 )
            {
                ERL_NIF_TERM ifname;
                unsigned char * bin = enif_make_new_binary( env, len, &ifname );
                if( bin != NULL )
                {
                    memcpy( bin, tmp, len );

                    ERL_NIF_TERM type = msg->event_code == KEV_DL_LINK_ON ? s_link_up : s_link_down;
                    ERL_NIF_TERM keys[2] = { s_type, s_ifname };
                    ERL_NIF_TERM vals[2] = { type, ifname };

                    ERL_NIF_TERM map;
                    if( enif_make_map_from_arrays( env, keys, vals, 2, &map ) )
                    {
                        *events = enif_make_list_cell( env, map, *events );
                        return enif_make_tuple2( env, s_ok, *events );
                    }
                }
            }
            break;
        }

        default:
            break;
    }

    ERL_NIF_TERM reason = enif_make_tuple2( env, s_unhandled_event, enif_make_int( env, msg->event_code ) );
    return enif_make_tuple2( env, s_error, reason );
}

static ERL_NIF_TERM parse_inet_event(ErlNifEnv *env, const struct kern_event_msg *msg, ERL_NIF_TERM *events)
{
    const struct kev_in_data *data = (void*)&msg->event_data[0];

    switch( msg->event_code )
    {
        case KEV_INET_NEW_ADDR:
        case KEV_INET_ADDR_DELETED:
        {
            char tmp[IFNAMSIZ] = { 0 };
            int len = snprintf(tmp, sizeof(tmp), "%s%u", data->link_data.if_name, data->link_data.if_unit);
            if( len >= 0 )
            {
                ERL_NIF_TERM ifname;
                unsigned char * bin = enif_make_new_binary( env, len, &ifname );
                if( bin != NULL )
                {
                    memcpy( bin, tmp, len );

                    uint8_t * octets = (uint8_t*)&data->ia_addr;
                    ERL_NIF_TERM addr = enif_make_tuple4( env, 
                        enif_make_int(env, octets[0]),
                        enif_make_int(env, octets[1]),
                        enif_make_int(env, octets[2]),
                        enif_make_int(env, octets[3]) );
                    ERL_NIF_TERM type = msg->event_code == KEV_INET_ADDR_DELETED? s_del_addr : s_new_addr;
                    ERL_NIF_TERM keys[3] = { s_type, s_ifname, s_addr };
                    ERL_NIF_TERM vals[3] = { type, ifname, addr };

                    ERL_NIF_TERM map;
                    if( enif_make_map_from_arrays( env, keys, vals, 3, &map ) )
                    {
                        *events = enif_make_list_cell( env, map, *events );
                        return enif_make_tuple2( env, s_ok, *events );
                    }
                }
            }
            break;
        }
        default:
            break;
    }

    ERL_NIF_TERM reason = enif_make_tuple2( env, s_unhandled_event, enif_make_int( env, msg->event_code ) );
    return enif_make_tuple2( env, s_error, reason );
}

static ERL_NIF_TERM parse_inet6_event(ErlNifEnv *env, const struct kern_event_msg *msg, ERL_NIF_TERM *events)
{
    ERL_NIF_TERM *event_name = NULL;
    switch( msg->event_code )
    {
        case KEV_INET6_NEW_USER_ADDR:
        case KEV_INET6_NEW_LL_ADDR:
            event_name = &s_new_addr;
            break;
        case KEV_INET6_ADDR_DELETED:
            event_name = &s_del_addr;
            break;
        default:
            break;
    }


    if( NULL != event_name )
    {
        const struct kev_in6_data *data = (void*)&msg->event_data[0];
        char tmp[IFNAMSIZ] = { 0 };
        const int len = snprintf(tmp, sizeof(tmp), "%s%u", data->link_data.if_name, data->link_data.if_unit);
        if( len >= 0 )
        {
            ERL_NIF_TERM ifname;
            unsigned char * bin = enif_make_new_binary( env, len, &ifname );
            if( bin != NULL )
            {
                memcpy( bin, tmp, len );

                uint16_t const * hextets = data->ia_addr.sin6_addr.__u6_addr.__u6_addr16;
                ERL_NIF_TERM addr = enif_make_tuple8( env, 
                    enif_make_int(env, ntohs(hextets[0])),
                    enif_make_int(env, ntohs(hextets[1])),
                    enif_make_int(env, ntohs(hextets[2])),
                    enif_make_int(env, ntohs(hextets[3])),
                    enif_make_int(env, ntohs(hextets[4])),
                    enif_make_int(env, ntohs(hextets[5])),
                    enif_make_int(env, ntohs(hextets[6])),
                    enif_make_int(env, ntohs(hextets[7]))
                );
                ERL_NIF_TERM keys[3] = { s_type, s_ifname, s_addr };
                ERL_NIF_TERM vals[3] = { *event_name, ifname, addr };

                ERL_NIF_TERM map;
                if( enif_make_map_from_arrays( env, keys, vals, 3, &map ) )
                {
                    *events = enif_make_list_cell( env, map, *events );
                    return enif_make_tuple2( env, s_ok, *events );
                }
            }
        }
    }

    ERL_NIF_TERM reason = enif_make_tuple2( env, s_unhandled_event, enif_make_int( env, msg->event_code ) );
    return enif_make_tuple2( env, s_error, reason );
}

static ERL_NIF_TERM decode_event(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    ErlNifBinary bin;

    if( argc != 1 || !enif_inspect_binary( env, argv[ 0 ], &bin ) )
    {
        return enif_make_badarg( env );
    }
    const struct kern_event_msg * msg = ( void * )bin.data;

    // Check sizes before proceeding. The binary should be exactly the allocated
    // size of the kern_event_msg struct.
    if( bin.size < sizeof( *msg ) || bin.size != msg->total_size )
    {
        return enif_make_badarg( env );
    }

    ERL_NIF_TERM events = enif_make_list( env, 0 );

    if( msg->vendor_code  == KEV_VENDOR_APPLE && msg->kev_class  == KEV_NETWORK_CLASS )
    {
        switch( msg->kev_subclass )
        {
            case KEV_DL_SUBCLASS:
                return parse_dl_event( env, msg, &events );
            case KEV_INET_SUBCLASS:
                return parse_inet_event( env, msg, &events );
            case KEV_INET6_SUBCLASS:
                return parse_inet6_event( env, msg, &events );
            default:
                break;
        }
    }

    return enif_make_tuple2( env, s_error, s_unhandled_event );
}

static ErlNifFunc nif_funcs[] =
    {
        {"set_event_filter", 2, set_event_filter, 0},
        {"decode_event", 1, decode_event, 0},
    };

ERL_NIF_INIT(Elixir.Inertial.Monitor, nif_funcs, load, NULL, NULL, NULL)
