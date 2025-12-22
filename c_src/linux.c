#include <assert.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/if.h>
#include <linux/rtnetlink.h>
#include <erl_nif.h>
#include <erl_driver.h>

static ERL_NIF_TERM s_ok;
static ERL_NIF_TERM s_error;
static ERL_NIF_TERM s_failed;
static ERL_NIF_TERM s_groups;
static ERL_NIF_TERM s_type;
static ERL_NIF_TERM s_new_addr;
static ERL_NIF_TERM s_del_addr;
static ERL_NIF_TERM s_link_up;
static ERL_NIF_TERM s_link_down;
static ERL_NIF_TERM s_ifname;
static ERL_NIF_TERM s_addr;
static ERL_NIF_TERM s_unknown;

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
    s_groups = enif_make_atom(env, "groups");
    s_type = enif_make_atom(env, "type");
    s_new_addr = enif_make_atom(env, "new_addr");
    s_del_addr = enif_make_atom(env, "del_addr");
    s_link_up = enif_make_atom(env, "link_up");
    s_link_down = enif_make_atom(env, "link_down");
    s_ifname = enif_make_atom(env, "ifname");
    s_addr = enif_make_atom(env, "addr");
    s_unknown = enif_make_atom(env, "unknown");
    return 0;
}

static ERL_NIF_TERM set_event_filter(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int fd;
    if( argc != 2 || !enif_get_int( env, argv[0], &fd ) || !enif_is_map( env, argv[1] ) )
    {
        return enif_make_badarg( env );
    }

    struct sockaddr_nl local =
    {
        .nl_family = AF_NETLINK,
        .nl_pid = getpid()
    };

    ERL_NIF_TERM key, val;
    ErlNifMapIterator iter;
    enif_map_iterator_create( env, argv[ 1 ], &iter, ERL_NIF_MAP_ITERATOR_FIRST );
    while( enif_map_iterator_get_pair( env, &iter, &key, &val ) )
    {
        int ival;
        if( enif_get_int( env, val, &ival ) && ival >= 0 )
        {
            if( enif_compare( key, s_groups ) == 0 )
            {
                local.nl_groups = (uint32_t) ival;
            }
        }
        enif_map_iterator_next( env, &iter );
    }
    enif_map_iterator_destroy( env, &iter );

    if( bind( fd, (struct sockaddr *)&local, sizeof( local ) ) < 0 )
    {
        return make_error( env, errno );
    }
    
    return s_ok;
}

static ERL_NIF_TERM decode_event(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    ErlNifBinary bin;

    if( argc != 1 || !enif_inspect_binary( env, argv[ 0 ], &bin ) )
    {
        return enif_make_badarg( env );
    }

    ERL_NIF_TERM events = enif_make_list( env, 0 );
    
    struct nlmsghdr *nlh = (struct nlmsghdr *)bin.data;
    int len = bin.size;

    while( NLMSG_OK( nlh, len ) && nlh->nlmsg_type != NLMSG_DONE )
    {
        if( nlh->nlmsg_type == RTM_NEWADDR || nlh->nlmsg_type == RTM_DELADDR )
        {
            struct ifaddrmsg *ifa = NLMSG_DATA( nlh );
            struct rtattr *rth = IFA_RTA( ifa );
            int rtl = IFA_PAYLOAD( nlh );

            // Skip tentative IPv6 addresses (DAD in progress)
            if( ifa->ifa_family == AF_INET6 && (ifa->ifa_flags & IFA_F_TENTATIVE) )
            {
                nlh = NLMSG_NEXT( nlh, len );
                continue;
            }

            ERL_NIF_TERM type = nlh->nlmsg_type == RTM_NEWADDR ? s_new_addr : s_del_addr;
            ERL_NIF_TERM ifname = s_unknown;
            ERL_NIF_TERM addr = s_unknown;

            // Get interface name from index (needed for IPv6)
            char ifname_buf[IF_NAMESIZE];
            if( if_indextoname( ifa->ifa_index, ifname_buf ) != NULL )
            {
                unsigned char * dst = enif_make_new_binary( env, strlen( ifname_buf ), &ifname );
                memcpy( dst, ifname_buf, strlen( ifname_buf ) );
            }

            while( rtl && RTA_OK( rth, rtl ) )
            {
                if( rth->rta_type == IFA_LABEL )
                {
                    const char * src = RTA_DATA( rth );
                    unsigned char * dst = enif_make_new_binary( env, strlen( src ), &ifname );
                    memcpy( dst, src, strlen( src ) );
                }

                if( rth->rta_type == IFA_LOCAL || rth->rta_type == IFA_ADDRESS )
                {
                    if( ifa->ifa_family == AF_INET )
                    {
                        const uint8_t * octets = RTA_DATA( rth );
                        addr = enif_make_tuple4( env,
                                enif_make_int(env, octets[0]),
                                enif_make_int(env, octets[1]),
                                enif_make_int(env, octets[2]),
                                enif_make_int(env, octets[3]) );
                    }
                    else if( ifa->ifa_family == AF_INET6 )
                    {
                        const uint16_t * segments = RTA_DATA( rth );
                        addr = enif_make_tuple8( env,
                                enif_make_int(env, ntohs(segments[0])),
                                enif_make_int(env, ntohs(segments[1])),
                                enif_make_int(env, ntohs(segments[2])),
                                enif_make_int(env, ntohs(segments[3])),
                                enif_make_int(env, ntohs(segments[4])),
                                enif_make_int(env, ntohs(segments[5])),
                                enif_make_int(env, ntohs(segments[6])),
                                enif_make_int(env, ntohs(segments[7])) );
                    }
                }

                rth = RTA_NEXT( rth, rtl );
            }

            if( enif_is_binary( env, ifname ) && enif_is_tuple( env, addr ) )
            {
                ERL_NIF_TERM keys[3] = { s_type, s_ifname, s_addr };
                ERL_NIF_TERM vals[3] = { type, ifname, addr };

                ERL_NIF_TERM map;
                if( enif_make_map_from_arrays( env, keys, vals, 3, &map ) )
                {
                    events = enif_make_list_cell( env, map, events );
                }
            }
        }
        else if( nlh->nlmsg_type == RTM_NEWLINK || nlh->nlmsg_type == RTM_DELLINK )
        {
            struct ifinfomsg *ifi = NLMSG_DATA( nlh );

            // Skip messages where ifi_change is 0xFFFFFFFF (initial state dump)
            // or 0 (no actual change)
            if( ifi->ifi_change == 0 || ifi->ifi_change == 0xFFFFFFFF )
            {
                nlh = NLMSG_NEXT( nlh, len );
                continue;
            }

            // Only process if link state flags (IFF_UP or IFF_RUNNING) actually changed
            if( !(ifi->ifi_change & (IFF_UP | IFF_RUNNING)) )
            {
                nlh = NLMSG_NEXT( nlh, len );
                continue;
            }

            // Get interface name
            char ifname_buf[IF_NAMESIZE];
            ERL_NIF_TERM ifname = s_unknown;
            if( if_indextoname( ifi->ifi_index, ifname_buf ) != NULL )
            {
                unsigned char * dst = enif_make_new_binary( env, strlen( ifname_buf ), &ifname );
                memcpy( dst, ifname_buf, strlen( ifname_buf ) );
            }

            // Determine current link state
            // IFF_UP means administratively up, IFF_RUNNING means carrier detected
            int is_up = (ifi->ifi_flags & IFF_UP) && (ifi->ifi_flags & IFF_RUNNING);
            ERL_NIF_TERM type = is_up ? s_link_up : s_link_down;

            if( enif_is_binary( env, ifname ) )
            {
                ERL_NIF_TERM keys[2] = { s_type, s_ifname };
                ERL_NIF_TERM vals[2] = { type, ifname };

                ERL_NIF_TERM map;
                if( enif_make_map_from_arrays( env, keys, vals, 2, &map ) )
                {
                    events = enif_make_list_cell( env, map, events );
                }
            }
        }
        nlh = NLMSG_NEXT( nlh, len );
    }

    return enif_make_tuple2( env, s_ok, events );
}

static ErlNifFunc nif_funcs[] =
    {
        {"set_event_filter", 2, set_event_filter, 0},
        {"decode_event", 1, decode_event, 0},
    };

ERL_NIF_INIT(Elixir.Inertial.Monitor, nif_funcs, load, NULL, NULL, NULL)
