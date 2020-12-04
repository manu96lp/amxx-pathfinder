#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <reapi>
#include <xs>
#include <pathfinder>

/* ===========================================================================
* 				[ Global ]
* ============================================================================ */

#define IsPlayer(%0) 				( 1 <= %0 <= MAX_PLAYERS )

#define GetPlayerBit(%0,%1) 		( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1) 		( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1) 		( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )

#define ClientPlaySound(%0,%1) 		client_cmd( %0, "spk %s", %1 )

#define IsNodeSelected(%0) 			( ( %0 == g_iSelectedNode[ 0 ] ) || ( %0 == g_iSelectedNode[ 1 ] ) )
#define IsNodeNearOrigin(%0,%1) 	( xs_vec_distance_2d( g_eNodes[ %0 ][ Node_Origin ], %1 ) < 8.0 )

const TASK_SHOWNODES = 111;

const Float:MIN_VALID_UNITS = 4.0;
const Float:NODE_VIEW_DISTANCE = 2048.0;

enum _:Node_Struct
{
	Float:Node_Origin[ 3 ],
	Node_Link_Count,
	Node_Link[ MAX_NODE_LINKS ],
	Float:Node_Link_Distance[ MAX_NODE_LINKS ]
}

new const g_szPrefix[ ] 		= "PF";

new const g_szErrorSound[ ] 	= "buttons/button10.wav";
new const g_szSelectSound[ ] 	= "common/menu1.wav";

new const g_eNullNode[ Node_Struct ];

new g_iNodesCount;
new g_iBeamSprite;
new g_iSelectedNode[ 2 ];
new g_eNodes[ MAX_NODES ][ Node_Struct ];

/* ===========================================================================
* 				[ Plugin forwards ]
* ============================================================================ */

public plugin_natives( )
{
	register_native( "GeneratePath", "__GeneratePath" );
	
	register_native( "GetNodeCount", "__GetNodeCount" );
	register_native( "GetNodeOrigin", "__GetNodeOrigin" );
	register_native( "GetNodeLink", "__GetNodeLink" );
	register_native( "GetNodeLinkCount", "__GetNodeLinkCount" );
}

public plugin_precache( )
{
	g_iBeamSprite = precache_model( "sprites/laserbeam.spr" );
	
	precache_sound( g_szErrorSound );
	precache_sound( g_szSelectSound );
}

public plugin_init( )
{
	register_plugin( "Path Finder", "1.0", "Manu" );
	
	register_clcmd( "pf_menu", "ClientCommand_MainMenu" );
	register_clcmd( "say /pf_menu", "ClientCommand_MainMenu" );
	
	VerifyDirectories( );
	
	g_iSelectedNode[ 0 ] = -1;
	g_iSelectedNode[ 1 ] = -1;
}

public plugin_cfg( )
{
	LoadNodes( );
	LoadLinks( );
}

/* ===========================================================================
* 				[ Tasks ]
* ============================================================================ */

public OnTaskShowNodes( iTask )
{
	new iId = ( iTask - TASK_SHOWNODES );
	
	if( !is_user_connected( iId ) )
	{
		return;
	}
	
	new Float:flOrigin[ 3 ];
	
	get_entvar( iId, var_origin, flOrigin );
	
	new iLink;
	new iGreen;
	
	new bool:bDisplayed[ MAX_NODES ];
	
	for( new i = 0, j = 0; i < g_iNodesCount; i++ )
	{
		if( xs_vec_distance( flOrigin, g_eNodes[ i ][ Node_Origin ] ) > NODE_VIEW_DISTANCE )
		{
			continue;
		}
		
		( g_iSelectedNode[ 0 ] != i ) ? ( g_iSelectedNode[ 1 ] != i ) ?
			( iGreen = 255 ) : ( iGreen = 127 ) : ( iGreen = 0 );
		
		message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, iId );
		write_byte( TE_BEAMPOINTS );
		write_coord_f( g_eNodes[ i ][ Node_Origin ][ 0 ] );
		write_coord_f( g_eNodes[ i ][ Node_Origin ][ 1 ] );
		write_coord_f( g_eNodes[ i ][ Node_Origin ][ 2 ] - 32.0 );
		write_coord_f( g_eNodes[ i ][ Node_Origin ][ 0 ] );
		write_coord_f( g_eNodes[ i ][ Node_Origin ][ 1 ] );
		write_coord_f( g_eNodes[ i ][ Node_Origin ][ 2 ] + 32.0 );
		write_short( g_iBeamSprite );
		write_byte( 0 );
		write_byte( 0 );
		write_byte( 10 );
		write_byte( 50 );
		write_byte( 0 );
		write_byte( 255 );
		write_byte( iGreen );
		write_byte( 0 );
		write_byte( 200 );
		write_byte( 0 );
		message_end( );
		
		bDisplayed[ i ] = true;
		
		for( j = 0; j < g_eNodes[ i ][ Node_Link_Count ]; j++ )
		{
			iLink = g_eNodes[ i ][ Node_Link ][ j ];
			
			if( bDisplayed[ iLink ] )
			{
				continue;
			}
			
			message_begin( MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, iId );
			write_byte( TE_BEAMPOINTS );
			write_coord_f( g_eNodes[ i ][ Node_Origin ][ 0 ] );
			write_coord_f( g_eNodes[ i ][ Node_Origin ][ 1 ] );
			write_coord_f( g_eNodes[ i ][ Node_Origin ][ 2 ] );
			write_coord_f( g_eNodes[ iLink ][ Node_Origin ][ 0 ] );
			write_coord_f( g_eNodes[ iLink ][ Node_Origin ][ 1 ] );
			write_coord_f( g_eNodes[ iLink ][ Node_Origin ][ 2 ] );
			write_short( g_iBeamSprite );
			write_byte( 0 ) ;
			write_byte( 0 );
			write_byte( 10 );
			write_byte( 10 );
			write_byte( 0 );
			write_byte( 255 );
			write_byte( 185 );
			write_byte( 0 );
			write_byte( 200 );
			write_byte( 0 );
			message_end( );
		}
	}
}

/* ===========================================================================
* 				[ Client commands ]
* ============================================================================ */

public ClientCommand_MainMenu( iId )
{
	if( ~get_user_flags( iId ) & ADMIN_RCON )
	{
		return PLUGIN_HANDLED;
	}
	
	ShowMainMenu( iId );
	
	return PLUGIN_HANDLED;
}

/* ===========================================================================
* 				[ Client menus ]
* ============================================================================ */

ShowMainMenu( iId )
{
	new iMenu = menu_create( "Path Finder", "MainMenuHandler" );
	
	menu_additem( iMenu, "Revelar nodos" );
	menu_additem( iMenu, "Ocultar nodos^n" );
	
	menu_additem( iMenu, "Crear nodo^n" );
	
	menu_additem( iMenu, "Seleccionar nodo principal" );
	menu_additem( iMenu, "Seleccionar nodo secundario^n" );
	
	menu_additem( iMenu, "Crear enlace^n" );
	
	menu_additem( iMenu, "Remover nodo" );
	menu_additem( iMenu, "Remover enlaces^n" );
	
	menu_additem( iMenu, "Guardar" );
	
	menu_setprop( iMenu, MPROP_PERPAGE, 0 );
	menu_setprop( iMenu, MPROP_EXIT, MEXIT_FORCE );
	menu_setprop( iMenu, MPROP_EXITNAME, "Cancelar" );
	
	menu_display( iId, iMenu );
	
	return PLUGIN_HANDLED;
}

public MainMenuHandler( iId, iMenu, iItem )
{
	menu_destroy( iMenu );
	
	if( iItem == MENU_EXIT )
	{
		return PLUGIN_HANDLED;
	}
	
	new Float:flOrigin[ 3 ];
	
	switch( iItem )
	{
		case( 0 ):
		{
			set_task( 1.0, "OnTaskShowNodes", iId + TASK_SHOWNODES, .flags = "b" );
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Los nodos y enlaces lejanos no seran visibles.", g_szPrefix );
			client_print_color( iId, print_team_default, "^4[%s]^1 Se iran actualizando los nodos que puedes ver a medida que te muevas.", g_szPrefix );
		}
		case( 1 ):
		{
			if( task_exists( iId + TASK_SHOWNODES ) )
			{
				remove_task( iId + TASK_SHOWNODES );
			}
		}
		case( 2 ):
		{
			if( g_iNodesCount == MAX_NODES )
			{
				ClientPlaySound( iId, g_szErrorSound );
				
				client_print_color( iId, print_team_default, "^4[%s]^1 Ya se alcanzo el limite de nodos (%d).", g_szPrefix, MAX_NODES );
				client_print_color( iId, print_team_default, "^4[%s]^1 Borra algun nodo o incrementa el limite de estos.", g_szPrefix );
				
				goto end;
			}
			
			GetAimOrigin( iId, flOrigin );
			
			flOrigin[ 2 ] += 36.0;
			
			if( !IsHullVacant( flOrigin ) )
			{
				ClientPlaySound( iId, g_szErrorSound );
				
				client_print_color( iId, print_team_default, "^4[%s]^1 No se puede crear un nodo en esa ubicacion.", g_szPrefix );
				client_print_color( iId, print_team_default, "^4[%s]^1 Busca otro lugar con mas espacio.", g_szPrefix );
				
				goto end;
			}
			
			g_eNodes[ g_iNodesCount ][ Node_Origin ][ 0 ] = flOrigin[ 0 ];
			g_eNodes[ g_iNodesCount ][ Node_Origin ][ 1 ] = flOrigin[ 1 ];
			g_eNodes[ g_iNodesCount ][ Node_Origin ][ 2 ] = flOrigin[ 2 ];
			
			g_iNodesCount++;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Nodo creado correctamente.", g_szPrefix );
		}
		case 3..4:
		{
			new iClosest = -1;
			
			new Float:flClosest = 9999.0;
			new Float:flDistance = 0.0;
			
			GetAimOrigin( iId, flOrigin );
			
			for( new i = 0; i < g_iNodesCount; i++ )
			{
				flDistance = xs_vec_distance( flOrigin, g_eNodes[ i ][ Node_Origin ] );
				
				if( flDistance > 127.0 )
				{
					continue;
				}
				
				if( flDistance > flClosest )
				{
					continue;
				}
				
				iClosest = i;
				flClosest = flDistance;
			}
			
			if( iClosest == -1 )
			{
				ClientPlaySound( iId, g_szErrorSound );
				
				client_print_color( iId, print_team_default, "^4[%s]^1 No se encontro ningun nodo cercano.", g_szPrefix );
				
				goto end;
			}
			
			g_iSelectedNode[ ( iItem - 3 ) ] = iClosest;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Nodo^4 (%d)^1 seleccionado correctamente.", g_szPrefix, iClosest );
		}
		case( 5 ):
		{
			if( !CanCreateLink( ) )
			{
				ClientPlaySound( iId, g_szErrorSound );
				
				client_print_color( iId, print_team_default, "^4[%s]^1 No se pudo crear un enlace entre los nodos.", g_szPrefix );
				client_print_color( iId, print_team_default, "^4[%s]^1 Asegurate de haber seleccionado cada uno de forma correcta.", g_szPrefix );
				
				goto end;
			}
			
			new Float:flDistance = xs_vec_distance( g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Origin ], g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Origin ] );
			
			g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link ][ g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ] ] = g_iSelectedNode[ 1 ];
			g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link ][ g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link_Count ] ] = g_iSelectedNode[ 0 ];
			
			g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Distance ][ g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ] ] = flDistance;
			g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link_Distance ][ g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link_Count ] ] = flDistance;
			
			g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ]++;
			g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link_Count ]++;
			
			g_iSelectedNode[ 0 ] = -1;
			g_iSelectedNode[ 1 ] = -1;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Enlace creado correctamente.", g_szPrefix );
		}
		case( 6 ):
		{
			if( ( g_iSelectedNode[ 0 ] == -1 ) || ( g_iSelectedNode[ 0 ] >= g_iNodesCount ) )
			{
				ClientPlaySound( iId, g_szErrorSound );
				
				client_print_color( iId, print_team_default, "^4[%s]^1 No tienes ningun nodo seleccionado.", g_szPrefix );
				
				goto end;
			}
			
			new iNode;
			new iCount;
			
			for( new i = 0, j = 0; i < g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ]; i++ )
			{
				iNode = g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link ][ i ];
				iCount = g_eNodes[ iNode ][ Node_Link_Count ];
				
				for( j = 0; j < iCount; j++ )
				{
					if( g_eNodes[ iNode ][ Node_Link ][ j ] != g_iSelectedNode[ 0 ] )
					{
						continue;
					}
					
					if( j < ( iCount - 1 ) )
					{
						g_eNodes[ iNode ][ Node_Link ][ j ] = g_eNodes[ iNode ][ Node_Link ][ iCount - 1 ];
						g_eNodes[ iNode ][ Node_Link_Distance ][ j ] = g_eNodes[ iNode ][ Node_Link_Distance ][ iCount - 1 ];
					}
					
					g_eNodes[ iNode ][ Node_Link ][ iCount - 1 ] = 0;
					g_eNodes[ iNode ][ Node_Link_Distance ][ iCount - 1 ] = 0.0;
					
					g_eNodes[ iNode ][ Node_Link_Count ]--;
					
					break;
				}
			}
			
			g_iNodesCount--;
			
			for( new i = g_iSelectedNode[ 0 ]; i < g_iNodesCount; i++ )
			{
				g_eNodes[ i ] = g_eNodes[ i + 1 ];
			}
			
			g_eNodes[ g_iNodesCount ] = g_eNullNode;
			
			for( new i = 0, j = 0; i < g_iNodesCount; i++ )
			{
				for( j = 0; j < g_eNodes[ i ][ Node_Link_Count ]; j++ )
				{
					if( g_iSelectedNode[ 0 ] < g_eNodes[ i ][ Node_Link ][ j ] )
					{
						g_eNodes[ i ][ Node_Link ][ j ]--;
					}
				}
			}
			
			g_iSelectedNode[ 0 ] = -1;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Eliminaste el nodo correctamente.", g_szPrefix );
		}
		case( 7 ):
		{
			if( ( g_iSelectedNode[ 0 ] == -1 ) || ( g_iSelectedNode[ 0 ] >= g_iNodesCount ) )
			{
				ClientPlaySound( iId, g_szErrorSound );
				
				client_print_color( iId, print_team_default, "^4[%s]^1 No tienes ningun nodo seleccionado.", g_szPrefix );
				
				goto end;
			}
			
			new iNode;
			new iCount;
			
			for( new i = 0, j = 0; i < g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ]; i++ )
			{
				iNode = g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link ][ i ];
				iCount = g_eNodes[ iNode ][ Node_Link_Count ];
				
				for( j = 0; j < iCount; j++ )
				{
					if( g_eNodes[ iNode ][ Node_Link ][ j ] != g_iSelectedNode[ 0 ] )
					{
						continue;
					}
					
					if( j < ( iCount - 1 ) )
					{
						g_eNodes[ iNode ][ Node_Link ][ j ] = g_eNodes[ iNode ][ Node_Link ][ iCount - 1 ];
						g_eNodes[ iNode ][ Node_Link_Distance ][ j ] = g_eNodes[ iNode ][ Node_Link_Distance ][ iCount - 1 ];
					}
					
					g_eNodes[ iNode ][ Node_Link ][ iCount - 1 ] = 0;
					g_eNodes[ iNode ][ Node_Link_Distance ][ iCount - 1 ] = 0.0;
					
					g_eNodes[ iNode ][ Node_Link_Count ]--;
					
					break;
				}
			}
			
			g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ] = 0;
			
			g_iSelectedNode[ 0 ] = -1;
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Eliminaste los enlaces del nodo correctamente.", g_szPrefix );
		}
		case( 8 ):
		{
			SaveNodes( );
			SaveLinks( );
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Guardaste correctamente^4 (%d)^1 nodos.", g_szPrefix, g_iNodesCount );
		}
	}
	
	ClientPlaySound( iId, g_szSelectSound );
	
	end:
	
	ShowMainMenu( iId );
	
	return PLUGIN_HANDLED;
}

/* ===========================================================================
* 				[ Verify directories ]
* ============================================================================ */

VerifyDirectories( )
{
	new const szDirectories[ ][ ] =
	{
		"/pathfinder",
		"/pathfinder/nodes",
		"/pathfinder/links"
	}
	
	new szRoute[ 128 ];
	new szBaseDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szBaseDir, charsmax( szBaseDir ) );
	
	for( new i = 0; i < sizeof( szDirectories ); i++ )
	{
		formatex( szRoute, charsmax( szRoute ), "%s%s", szBaseDir, szDirectories[ i ] );
		
		if( !dir_exists( szRoute ) )
		{
			mkdir( szRoute );
		}
	}
}

/* ===========================================================================
* 				[ Data loading ]
* ============================================================================ */

LoadNodes( )
{
	new szFile[ 128 ];
	
	new szMap[ 32 ];
	new szDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szDir, charsmax( szDir ) );
	get_mapname( szMap, charsmax( szMap ) );
	
	formatex( szFile, charsmax( szFile ), "%s/pathfinder/nodes/%s.dat", szDir, szMap );
	
	if( !file_exists( szFile ) )
	{
		return;
	}
	
	new szData[ 64 ];
	new szOrigin[ 3 ][ 8 ];
	
	new iFile = fopen( szFile, "rt" );
	
	while( !feof( iFile ) )
	{
		fgets( iFile, szData, charsmax( szData ) );
		
		if( strlen( szData ) < 4 )
		{
			continue;
		}
		
		parse( szData, szOrigin[ 0 ], charsmax( szOrigin[ ] ), szOrigin[ 1 ], charsmax( szOrigin[ ] ), szOrigin[ 2 ], charsmax( szOrigin[ ] ) );
		
		g_eNodes[ g_iNodesCount ][ Node_Origin ][ 0 ] = str_to_float( szOrigin[ 0 ] );
		g_eNodes[ g_iNodesCount ][ Node_Origin ][ 1 ] = str_to_float( szOrigin[ 1 ] );
		g_eNodes[ g_iNodesCount ][ Node_Origin ][ 2 ] = str_to_float( szOrigin[ 2 ] );
		
		g_iNodesCount++;
	}
	
	fclose( iFile );
}

LoadLinks( )
{
	new szFile[ 128 ];
	
	new szMap[ 32 ];
	new szDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szDir, charsmax( szDir ) );
	get_mapname( szMap, charsmax( szMap ) );
	
	formatex( szFile, charsmax( szFile ), "%s/pathfinder/links/%s.dat", szDir, szMap );
	
	if( !file_exists( szFile ) )
	{
		return;
	}
	
	new szData[ 128 ];
	
	new szNode[ 8 ];
	new szCount[ 8 ];
	
	new szLink[ 8 ];
	new szDistance[ 8 ];
	
	new iNode;
	new iCount;
	
	new i;
	
	new iFile = fopen( szFile, "rt" );
	
	while( !feof( iFile ) )
	{
		fgets( iFile, szData, charsmax( szData ) );
		
		if( strlen( szData ) < 4 )
		{
			continue;
		}
		
		strtok2( szData, szNode, charsmax( szNode ), szData, charsmax( szData ), ' ', TRIM_FULL );
		strtok2( szData, szCount, charsmax( szCount ), szData, charsmax( szData ), ' ', TRIM_FULL );
		
		iNode = str_to_num( szNode );
		iCount = str_to_num( szCount );
		
		for( i = 0; i < iCount; i++ )
		{
			strtok2( szData, szLink, charsmax( szLink ), szData, charsmax( szData ), ' ', TRIM_FULL );
			strtok2( szData, szDistance, charsmax( szDistance ), szData, charsmax( szData ), ' ', TRIM_FULL );
			
			g_eNodes[ iNode ][ Node_Link ][ i ] = str_to_num( szLink );
			g_eNodes[ iNode ][ Node_Link_Distance ][ i ] = str_to_float( szDistance );
			
			g_eNodes[ iNode ][ Node_Link_Count ]++;
		}
	}
	
	fclose( iFile );
}

/* ===========================================================================
* 				[ Data saving ]
* ============================================================================ */

SaveNodes( )
{
	new szFile[ 128 ];
	
	new szMap[ 32 ];
	new szDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szDir, charsmax( szDir ) );
	get_mapname( szMap, charsmax( szMap ) );
	
	formatex( szFile, charsmax( szFile ), "%s/pathfinder/nodes/%s.dat", szDir, szMap );
	
	new iFile = fopen( szFile, "wt" );
	
	for( new i = 0; i < g_iNodesCount; i++ )
	{
		fprintf( iFile, "%0.1f %0.1f %0.1f^n",
			g_eNodes[ i ][ Node_Origin ][ 0 ],
			g_eNodes[ i ][ Node_Origin ][ 1 ],
			g_eNodes[ i ][ Node_Origin ][ 2 ] );
	}
	
	fclose( iFile );
}

SaveLinks( )
{
	new szFile[ 128 ];
	
	new szMap[ 32 ];
	new szDir[ 64 ];
	
	get_localinfo( "amxx_datadir", szDir, charsmax( szDir ) );
	get_mapname( szMap, charsmax( szMap ) );
	
	formatex( szFile, charsmax( szFile ), "%s/pathfinder/links/%s.dat", szDir, szMap );
	
	new iFile = fopen( szFile, "wt" );
	
	for( new i = 0, j = 0; i < g_iNodesCount; i++ )
	{
		fprintf( iFile, "%d %d", i, g_eNodes[ i ][ Node_Link_Count ] );
		
		for( j = 0; j < g_eNodes[ i ][ Node_Link_Count ]; j++ )
		{
			fprintf( iFile, " %d %0.1f", g_eNodes[ i ][ Node_Link ][ j ], g_eNodes[ i ][ Node_Link_Distance ][ j ] );
		}
		
		fprintf( iFile, "^n" );
	}
	
	fclose( iFile );
}

/* ===========================================================================
* 				[ Path modules ]
* ============================================================================ */

_GeneratePath( const Float:flStart[ 3 ], const Float:flEnd[ 3 ], &Array:aResult )
{
	new iClosestToEnd = -1;
	new iClosestToStart = -1;
	
	new Float:flClosestToEnd = 9999.0;
	new Float:flClosestToStart = 9999.0;
	
	new Float:flDistance = 0.0;
	
	for( new i = 0; i < g_iNodesCount; i++ )
	{
		flDistance = xs_vec_distance( g_eNodes[ i ][ Node_Origin ], flEnd );
		
		if( flDistance < flClosestToEnd )
		{
			if( !IsWallBetween( g_eNodes[ i ][ Node_Origin ], flEnd ) )
			{
				flClosestToEnd = flDistance;
				iClosestToEnd = i;
			}
		}
		
		flDistance = xs_vec_distance( g_eNodes[ i ][ Node_Origin ], flStart );
		
		if( flDistance < flClosestToStart )
		{
			if( !IsWallBetween( g_eNodes[ i ][ Node_Origin ], flStart ) )
			{
				flClosestToStart = flDistance;
				iClosestToStart = i;
			}
		}
	}
	
	if( ( iClosestToEnd == -1 ) || ( iClosestToStart == -1 ) )
	{
		return false;
	}
	
	new Array:aPathGroup = ArrayCreate( 1, 1 );
	new Array:aPath = ArrayCreate( 1, 1 );
	new Array:aOther = Invalid_Array;
	
	new iPos;
	new iNode;
	new iLink;
	new iSize;
	new iOther;
	new iDistance;
	new iPathCount;
	new iClosestDistance;
	
	new bool:bAdded;
	new bool:bChanges;
	
	new iTraveled[ MAX_NODES ];
	new bool:bVisited[ MAX_NODES ];
	
	ArrayPushCell( aPath, iClosestToStart );
	ArrayPushCell( aPathGroup, aPath );
	
	bVisited[ iClosestToStart ] = true;
	bChanges = true;
	
	iPathCount++;
	
	new i, j, k;
	
	while( bChanges )
	{
		bChanges = false;
		
		for( i = 0; i < iPathCount; i++ )
		{
			aPath = ArrayGetCell( aPathGroup, i );
			
			iSize = ArraySize( aPath );
			iNode = ArrayGetCell( aPath, ( iSize - 1 ) );
			
			if( iNode == iClosestToEnd )
			{
				iClosestDistance = iTraveled[ iNode ];
				
				continue;
			}
			
			bAdded = false;
			
			for( j = 0; j < g_eNodes[ iNode ][ Node_Link_Count ]; j++ )
			{
				iLink = g_eNodes[ iNode ][ Node_Link ][ j ];
				iDistance = ( iTraveled[ iNode ] + floatround( g_eNodes[ iNode ][ Node_Link_Distance ][ j ] ) );
				
				if( bVisited[ iLink ] )
				{
					if( ( iTraveled[ iLink ] <= iDistance ) || ( iClosestDistance <= iDistance ) )
					{
						continue;
					}
					
					for( k = 0; k < iPathCount; k++ )
					{
						aOther = ArrayGetCell( aPathGroup, k );
						
						iSize = ArraySize( aOther );
						iPos = ArrayFindValue( aOther, iLink );
						
						if( iPos == -1 )
						{
							continue;
						}
						
						while( iPos < iSize )
						{
							iOther = ArrayGetCell( aOther, iPos );
							iSize = ( iSize - 1 );
							
							iTraveled[ iOther ] = 0;
							bVisited[ iOther ] = false;
							
							ArrayDeleteItem( aOther, iPos );
						}
						
						break;
					}
				}
				
				iTraveled[ iLink ] = iDistance;
				bVisited[ iLink ] = true;
				
				if( bAdded )
				{
					aOther = ArrayClone( aPath );
					iSize = ArraySize( aOther ); 
					
					ArrayDeleteItem( aOther, ( iSize - 1 ) );
					
					ArrayPushCell( aOther, iLink );
					ArrayPushCell( aPathGroup, aOther );
					
					iPathCount++;
				}
				else
				{
					ArrayPushCell( aPath, iLink );
				}
				
				bAdded = true;
				bChanges = true;
			}
		}
	}
	
	iNode = -1;
	aResult = Invalid_Array;
	iPathCount = ArraySize( aPathGroup );
	
	for( i = 0; i < iPathCount; i++ )
	{
		aPath = ArrayGetCell( aPathGroup, i );
		iSize = ArraySize( aPath );
		iNode = ArrayGetCell( aPath, ( iSize - 1 ) );
		
		if( iNode != iClosestToEnd )
		{
			continue;
		}
		
		aResult = ArrayCreate( 3, 1 );
		
		for( j = 0; j < iSize; j++ )
		{
			ArrayPushArray( aResult, g_eNodes[ ArrayGetCell( aPath, j ) ][ Node_Origin ] );
		}
		
		break;
	}
	
	for( i = 0; i < iPathCount; i++ )
	{
		aPath = ArrayGetCell( aPathGroup, i );
		
		ArrayDestroy( aPath );
	}
	
	ArrayDestroy( aPathGroup );
	
	return ( aResult != Invalid_Array );
}

/* ===========================================================================
* 				[ Link modules ]
* ============================================================================ */

bool:CanCreateLink( )
{
	if( ( g_iSelectedNode[ 0 ] == -1 )
	|| ( g_iSelectedNode[ 1 ] == -1 )
	|| ( g_iSelectedNode[ 0 ] >= g_iNodesCount )
	|| ( g_iSelectedNode[ 1 ] >= g_iNodesCount )
	|| ( g_iSelectedNode[ 0 ] == g_iSelectedNode[ 1 ] ) )
	{
		return false;
	}
	
	if( ( g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ] >= MAX_NODE_LINKS )
	|| ( g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link_Count ] >= MAX_NODE_LINKS ) )
	{
		return false;
	}
	
	if( IsWallBetween( g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Origin ], g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Origin ] ) )
	{
		return false;
	}
	
	if( ( g_eNodes[ g_iSelectedNode[ 0 ] ][ Node_Link_Count ] == 0 )
	|| ( g_eNodes[ g_iSelectedNode[ 1 ] ][ Node_Link_Count ] == 0 ) )
	{
		return true;
	}
	
	if( AreLinked( g_iSelectedNode[ 0 ], g_iSelectedNode[ 1 ] ) )
	{
		return false;
	}
	
	return true;
}

bool:AreLinked( iNode_1, iNode_2 )
{
	for( new i = 0; i < g_eNodes[ iNode_1 ][ Node_Link_Count ]; i++ )
	{
		if( g_eNodes[ iNode_1 ][ Node_Link ][ i ] == iNode_2 )
		{
			return true;
		}
	}
	
	return false;
}

/* ===========================================================================
* 				[ Random modules ]
* ============================================================================ */

GetAimOrigin( const iId, Float:flOrigin[ 3 ] )
{
	new Float:flStart[ 3 ];
	new Float:flEnd[ 3 ];
	new Float:flViewOfs[ 3 ];
	new Float:flAngles[ 3 ];
	
	get_entvar( iId, var_origin, flStart );
	get_entvar( iId, var_view_ofs, flViewOfs );
	get_entvar( iId, var_v_angle, flAngles );
	
	xs_vec_add( flStart, flViewOfs, flStart );
	
	angle_vector( flAngles, ANGLEVECTOR_FORWARD, flAngles );
	
	xs_vec_mul_scalar( flAngles, 2048.0, flAngles );
	xs_vec_add( flStart, flAngles, flEnd );
	
	trace_line( iId, flStart, flEnd, flOrigin );
}

bool:IsWallBetween( const Float:flThis[ ], const Float:flOther[ ] )
{
	new iHit = -1;
	
	new Float:flDistance;
	new Float:flTotalDistance;
	
	new Float:flStart[ 3 ];
	new Float:flResult[ 3 ];
	
	new Float:flEnd[ 3 ];
	
	xs_vec_copy( flThis, flStart );
	xs_vec_copy( flOther, flEnd );
	
	flTotalDistance = xs_vec_distance( flThis, flEnd );
	
	do
	{
		iHit = trace_line( iHit, flStart, flEnd, flResult );
		flDistance = ( xs_vec_distance( flResult, flThis ) + 16.0 );
		
		if( ( flTotalDistance - flDistance ) <= 16.0 )
		{
			return false;
		}
		
		xs_vec_sub( flEnd, flResult, flStart );
		xs_vec_normalize( flStart, flStart );
		xs_vec_mul_scalar( flStart, flDistance, flStart );
		xs_vec_add( flThis, flStart, flStart );
	}
	while( iHit > 0 )
	
	return true;
}

bool:IsHullVacant( const Float:flOrigin[ 3 ], const iHull = HULL_HUMAN )
{
	if( !trace_hull( flOrigin, iHull, _, IGNORE_MONSTERS ) )
	{
		return true;
	}
	
	return false;
}

/* ===========================================================================
* 				[ Path modules ]
* ============================================================================ */

public __GeneratePath( iPlugin, iParams )
{
	if( iParams != 3 )
	{
		log_error( AMX_ERR_PARAMS, "(%d) parameters. (3) expected.", iParams );
		
		return false;
	}
	
	new Array:aPath;
	
	new Float:flStart[ 3 ];
	new Float:flEnd[ 3 ];
	
	get_array_f( 1, flStart, 3 );
	get_array_f( 2, flEnd, 3 );
	
	if( _GeneratePath( flStart, flEnd, aPath ) )
	{
		set_param_byref( 3, _:aPath );
		
		return true;
	}
	
	return false;
}

public __GetNodeCount( iPlugin, iParams )
{
	if( iParams != 0 )
	{
		log_error( AMX_ERR_PARAMS, "(%d) parameters. (0) expected.", iParams );
		
		return 0;
	}
	
	return g_iNodesCount;
}

public __GetNodeOrigin( iPlugin, iParams )
{
	if( iParams != 2 )
	{
		log_error( AMX_ERR_PARAMS, "(%d) parameters. (2) expected.", iParams );
		
		return;
	}
	
	new iNode = get_param( 1 );
	
	if( !( 0 <= iNode < g_iNodesCount ) )
	{
		log_error( AMX_ERR_BOUNDS, "Node not found." );
		
		return;
	}
	
	new Float:flOrigin[ 3 ];
	
	flOrigin[ 0 ] = g_eNodes[ iNode ][ Node_Origin ][ 0 ];
	flOrigin[ 1 ] = g_eNodes[ iNode ][ Node_Origin ][ 1 ];
	flOrigin[ 2 ] = g_eNodes[ iNode ][ Node_Origin ][ 2 ];
	
	set_array_f( 2, flOrigin, 3 );
}

public __GetNodeLink( iPlugin, iParams )
{
	if( iParams != 4 )
	{
		log_error( AMX_ERR_PARAMS, "(%d) parameters. (4) expected.", iParams );
		
		return;
	}
	
	new iNode = get_param( 1 );
	new iLinkId = get_param( 2 );
	
	if( !( 0 <= iNode < g_iNodesCount ) || !( 0 <= iLinkId < g_eNodes[ iNode ][ Node_Link_Count ] ) )
	{
		log_error( AMX_ERR_BOUNDS, "Node or link index not found." );
		
		return;
	}
	
	set_param_byref( 3, g_eNodes[ iNode ][ Node_Link ][ iLinkId ] );
	set_float_byref( 4, g_eNodes[ iNode ][ Node_Link_Distance ][ iLinkId ] );
}

public __GetNodeLinkCount( iPlugin, iParams )
{
	if( iParams != 1 )
	{
		log_error( AMX_ERR_PARAMS, "(%d) parameters. (1) expected.", iParams );
		
		return 0;
	}
	
	new iNode = get_param( 1 );
	
	if( !( 0 <= iNode < g_iNodesCount ) )
	{
		log_error( AMX_ERR_BOUNDS, "Node not found." );
		
		return 0;
	}
	
	return g_eNodes[ iNode ][ Node_Link_Count ];
}